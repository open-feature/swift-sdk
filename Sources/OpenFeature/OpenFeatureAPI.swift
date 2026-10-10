import Combine
import Foundation

/// A global singleton which holds base configuration for the OpenFeature library.
/// Configuration here will be shared across all ``Client``s.
public class OpenFeatureAPI {
    // Sync queue to change state atomically
    private let stateQueue = DispatchQueue(label: "com.openfeature.state.queue")
    // Serial queue on which provider lifecycle calls (initialize, onContextSet) are executed.
    // Keeping them off stateQueue prevents long-running provider I/O from blocking state reads.
    private let providerLifecycleQueue = DispatchQueue(label: "com.openfeature.provider-lifecycle")
    // Queue on which api.observe() subscribers are invoked; avoids deadlock when handlers call back into the API.
    private let eventHandlerQueue = DispatchQueue(label: "com.openfeature.event-handlers")

    private(set) var providerSubject = CurrentValueSubject<FeatureProvider?, Never>(nil)
    private(set) var evaluationContext: EvaluationContext?
    private(set) var hooks: [any Hook] = []
    private var logger: (any OpenFeatureLogger)?

    /// The ``OpenFeatureAPI`` singleton
    static public let shared = OpenFeatureAPI()

    public init() {}

    /**
    Set provider and calls its `initialize` in a background thread.
    The previously set provider, if it is a different instance, is shut down first.
    Readiness can be determined from `getState` or listening for `ready` event.
    */
    public func setProvider(provider: FeatureProvider, initialContext: EvaluationContext?) {
        _ = setProviderInternal(provider: provider, initialContext: initialContext)
    }

    /**
    Set provider and calls its `initialize`.
    The previously set provider, if it is a different instance, is shut down first.
    This async function returns when the `initialize` from the provider is completed.
    */
    public func setProviderAndWait(provider: FeatureProvider, initialContext: EvaluationContext?) async {
        await setProviderInternal(provider: provider, initialContext: initialContext).value
    }

    /**
    Set provider and calls its `initialize` in a background thread.
    The previously set provider, if it is a different instance, is shut down first.
    Readiness can be determined from `getState` or listening for `ready` event.
    */
    public func setProvider(provider: FeatureProvider) {
        setProvider(provider: provider, initialContext: nil)
    }

    /**
    Set provider and calls its `initialize`.
    The previously set provider, if it is a different instance, is shut down first.
    This async function returns when the `initialize` from the provider is completed.
    */
    public func setProviderAndWait(provider: FeatureProvider) async {
        await setProviderAndWait(provider: provider, initialContext: nil)
    }

    public func getProvider() -> FeatureProvider? {
        return stateQueue.sync {
            self.providerSubject.value
        }
    }

    /**
    Clear provider and call its `shutdown` in a background thread.
    Hooks and the evaluation context are kept; use `shutdown()` to reset the whole API.
    */
    public func clearProvider() {
        _ = clearProviderInternal()
    }

    /**
    Clear provider and call its `shutdown`.
    This async function returns when the `shutdown` from the provider is completed.
    */
    public func clearProviderAndWait() async {
        await clearProviderInternal().value
    }

    /**
    Shut down the API: the current provider's `shutdown` is called in a background thread and all API state is
    reset — provider, hooks and evaluation context — leaving the API ready to be configured again. The logger is
    configuration rather than evaluation state and is kept. Subscribers of `observe()` receive no further events
    until a new provider is set.
    */
    public func shutdown() {
        _ = shutdownInternal()
    }

    /**
    Shut down the API and reset all its state.
    This async function returns when the `shutdown` from the provider is completed.
    */
    public func shutdownAndWait() async {
        await shutdownInternal().value
    }

    /// Removes the current provider atomically on stateQueue, then runs its `shutdown` on
    /// providerLifecycleQueue. Returns a Future that resolves when `shutdown` completes, or at once when no
    /// provider was set.
    private func clearProviderInternal() -> Future<Void, Never> {
        return stateQueue.sync {
            let previous = self.providerSubject.value
            self.providerSubject.send(nil)
            return self.shutdownLifecycle(of: previous)
        }
    }

    /// Resets provider, hooks and evaluation context atomically on stateQueue, then runs the previous provider's
    /// `shutdown` on providerLifecycleQueue. Returns a Future that resolves when `shutdown` completes, or at once
    /// when no provider was set.
    private func shutdownInternal() -> Future<Void, Never> {
        return stateQueue.sync {
            let previous = self.providerSubject.value
            self.providerSubject.send(nil)
            self.hooks.removeAll()
            self.evaluationContext = nil
            return self.shutdownLifecycle(of: previous)
        }
    }

    /// Runs `provider.shutdown()` on providerLifecycleQueue; resolves at once when there is no provider.
    private func shutdownLifecycle(of provider: FeatureProvider?) -> Future<Void, Never> {
        guard let provider = provider else {
            return Future { $0(.success(())) }
        }
        return runLifecycle {
            provider.shutdown()
        }
    }

    /// Whether both values are the same provider object. Value-type providers are never "the same instance", so
    /// on replacement they are shut down like any other previous provider.
    private func isSameInstance(_ lhs: FeatureProvider, _ rhs: FeatureProvider) -> Bool {
        return (lhs as AnyObject) === (rhs as AnyObject)
    }

    /**
    Set evaluation context and calls the provider's `onContextSet` in a background thread.
    Readiness can be determined from `getState` or listening for `contextChanged` event.
    */
    public func setEvaluationContext(evaluationContext: EvaluationContext) {
        _ = updateContext(evaluationContext: evaluationContext)
    }

    /**
    Set evaluation context and calls the provider's `onContextSet`.
    This async function returns when the `onContextSet` from the provider is completed.
    */
    public func setEvaluationContextAndWait(evaluationContext: EvaluationContext) async {
        await updateContext(evaluationContext: evaluationContext).value
    }

    public func getEvaluationContext() -> EvaluationContext? {
        return stateQueue.sync {
            self.evaluationContext
        }
    }

    public func getProviderStatus() -> ProviderStatus {
        return stateQueue.sync {
            self.providerSubject.value?.status ?? .notReady
        }
    }

    public func getProviderMetadata() -> ProviderMetadata? {
        return stateQueue.sync {
            self.providerSubject.value?.metadata
        }
    }

    public func getClient() -> Client {
        return OpenFeatureClient(openFeatureApi: self, name: nil, version: nil)
    }

    public func getClient(name: String?, version: String?) -> Client {
        return OpenFeatureClient(openFeatureApi: self, name: name, version: version)
    }

    public func addHooks(hooks: (any Hook)...) {
        stateQueue.sync {
            self.hooks.append(contentsOf: hooks)
        }
    }

    public func clearHooks() {
        stateQueue.sync {
            self.hooks.removeAll()
        }
    }

    internal func getHooks() -> [any Hook] {
        return stateQueue.sync {
            self.hooks
        }
    }

    /// Sets the global logger.
    ///
    /// This logger is used for flag evaluations unless a client or ``FlagEvaluationOptions`` provides its own.
    /// - Parameter logger: The logger handed to providers during flag evaluation, or `nil` to clear it.
    public func setLogger(_ logger: (any OpenFeatureLogger)?) {
        stateQueue.sync {
            self.logger = logger
        }
    }

    /// Returns the global logger set with ``setLogger(_:)``, or `nil` if none is set.
    public func getLogger() -> (any OpenFeatureLogger)? {
        return stateQueue.sync {
            self.logger
        }
    }

    public func observe() -> AnyPublisher<ProviderEvent, Never> {
        return
            providerSubject
            .map { $0?.observe() ?? Empty().eraseToAnyPublisher() }
            .switchToLatest()
            // providerSubject is updated on stateQueue, so we need to receive on a different queue.
            // Otherwise, handlers are called while stateQueue is already locked, which would deadlock
            // if the handler calls back into the API.
            .receive(on: eventHandlerQueue)
            .eraseToAnyPublisher()
    }

    internal func getState() -> OpenFeatureState {
        return stateQueue.sync {
            OpenFeatureState(
                provider: providerSubject.value,
                evaluationContext: evaluationContext,
                hooks: hooks,
                logger: logger
            )
        }
    }

    /// Updates state atomically on stateQueue, then runs the previous provider's `shutdown` (when it is a
    /// different instance) followed by the new provider's `initialize` on providerLifecycleQueue.
    /// Returns a Future that resolves when `initialize` completes.
    private func setProviderInternal(provider: FeatureProvider, initialContext: EvaluationContext? = nil)
        -> Future<Void, Never>
    {
        return stateQueue.sync {
            let previous = self.providerSubject.value
            self.providerSubject.send(provider)
            if let initialContext = initialContext {
                self.evaluationContext = initialContext
            }
            // From the send above, evaluations go to the new provider, so the previous one is no longer in use
            // and is shut down. Queuing it before `initialize` keeps lifecycle calls serialised. Re-setting the
            // same instance is not a replacement, so it is not shut down.
            if let previous = previous, !isSameInstance(previous, provider) {
                _ = self.shutdownLifecycle(of: previous)
            }
            return self.runLifecycle {
                provider.initialize(initialContext: initialContext)
            }
        }
    }

    /// Updates state atomically on stateQueue, then runs the provider's `onContextSet` on
    /// providerLifecycleQueue.
    /// Returns a Future that resolves when `onContextSet` completes.
    private func updateContext(evaluationContext: EvaluationContext) -> Future<Void, Never> {
        return stateQueue.sync {
            let oldContext = self.evaluationContext
            self.evaluationContext = evaluationContext
            guard let provider = self.providerSubject.value else {
                return Future { $0(.success(())) }
            }
            return self.runLifecycle {
                provider.onContextSet(oldContext: oldContext, newContext: evaluationContext)
            }
        }
    }

    /// Dispatches `work` to providerLifecycleQueue and returns a Future that resolves when it
    /// completes. `work` is a closure so that the provider Future is created on the lifecycle
    /// queue rather than the caller's queue.
    private func runLifecycle(_ work: @escaping () -> Future<Void, Never>) -> Future<Void, Never> {
        return Future { resolve in
            self.providerLifecycleQueue.async {
                var cancelable: AnyCancellable?
                cancelable = work()
                    .sink { _ in
                        withExtendedLifetime(cancelable) {}
                        resolve(.success(()))
                    }
            }
        }
    }

    /// A consistent snapshot of the API state, read atomically for a single flag evaluation.
    internal struct OpenFeatureState {
        let provider: FeatureProvider?
        let evaluationContext: EvaluationContext?
        let hooks: [any Hook]
        let logger: (any OpenFeatureLogger)?
    }
}
