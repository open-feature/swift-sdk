import Combine
import Foundation

/// A global singleton which holds base configuration for the OpenFeature library.
/// Configuration here will be shared across all ``Client``s.
public class OpenFeatureAPI {
    private let eventHandler = EventHandler()
    private let stateQueue = DispatchQueue(label: "com.openfeature.state.queue")
    private let atomicOperationsQueue: AsyncSerialQueue

    private(set) var providerSubject = CurrentValueSubject<FeatureProvider?, Never>(nil)
    private(set) var evaluationContext: EvaluationContext?
    private(set) var providerStatus: ProviderStatus = .notReady
    private(set) var hooks: [any Hook] = []

    /// The ``OpenFeatureAPI`` singleton
    static public let shared = OpenFeatureAPI()

    public init() {
        // Check for OPENFEATURE_ASQ_VERBOSE environment variable to enable verbose logging
        let verboseMode = ProcessInfo.processInfo.environment["OPENFEATURE_ASQ_VERBOSE"] != nil
        atomicOperationsQueue = AsyncSerialQueue(verbose: verboseMode)
    }

    /**
    Set provider and calls its `initialize` in a background thread.
    Readiness can be determined from `getState` or listening for `ready` event.
    */
    public func setProvider(provider: FeatureProvider, initialContext: EvaluationContext?) {
        Task {
            await self.setProviderInternal(provider: provider, initialContext: initialContext)
        }
    }

    /**
    Set provider and calls its `initialize`.
    This async function returns when the `initialize` from the provider is completed.
    */
    public func setProviderAndWait(provider: FeatureProvider, initialContext: EvaluationContext?) async {
        await self.setProviderInternal(provider: provider, initialContext: initialContext)
    }

    /**
    Set provider and calls its `initialize` in a background thread.
    Readiness can be determined from `getState` or listening for `ready` event.
    */
    public func setProvider(provider: FeatureProvider) {
        setProvider(provider: provider, initialContext: nil)
    }

    /**
    Set provider and calls its `initialize`.
    This async function returns when the `initialize` from the provider is completed.
    */
    public func setProviderAndWait(provider: FeatureProvider) async {
        await setProviderAndWait(provider: provider, initialContext: nil)
    }

    public func getProvider() -> FeatureProvider? {
        return self.providerSubject.value
    }

    public func clearProvider() {
        // For synchronous API, we need to use the sync queue
        stateQueue.sync {
            self.providerSubject.send(nil)
            self.providerStatus = .notReady
        }
    }

    /**
    Set evaluation context and calls the provider's `onContextSet` in a background thread.
    Readiness can be determined from `getState` or listening for `contextChanged` event.
    */
    public func setEvaluationContext(evaluationContext: EvaluationContext) {
        Task {
            await self.updateContext(evaluationContext: evaluationContext)
        }
    }

    /**
    Set evaluation context and calls the provider's `onContextSet`.
    This async function returns when the `onContextSet` from the provider is completed.
    */
    public func setEvaluationContextAndWait(evaluationContext: EvaluationContext) async {
        await updateContext(evaluationContext: evaluationContext)
    }

    public func getEvaluationContext() -> EvaluationContext? {
        return self.evaluationContext
    }

    public func getProviderStatus() -> ProviderStatus {
        return self.providerStatus
    }

    public func getProviderMetadata() -> ProviderMetadata? {
        return self.getProvider()?.metadata
    }

    public func getClient() -> Client {
        return OpenFeatureClient(openFeatureApi: self, name: nil, version: nil)
    }

    public func getClient(name: String?, version: String?) -> Client {
        return OpenFeatureClient(openFeatureApi: self, name: name, version: version)
    }

    public func addHooks(hooks: (any Hook)...) {
        self.hooks.append(contentsOf: hooks)
    }

    public func clearHooks() {
        self.hooks.removeAll()
    }

    public func observe() -> AnyPublisher<ProviderEvent?, Never> {
        return providerSubject.map { provider in
            if let provider = provider {
                return provider.observe()
                    .merge(with: self.eventHandler.observe())
                    .eraseToAnyPublisher()
            } else {
                return Empty<ProviderEvent?, Never>()
                    .eraseToAnyPublisher()
            }
        }
        .switchToLatest()
        .eraseToAnyPublisher()
    }

    internal func getState() -> OpenFeatureState {
        return stateQueue.sync {
            OpenFeatureState(
                provider: providerSubject.value,
                evaluationContext: evaluationContext,
                providerStatus: providerStatus)
        }
    }

    private func setProviderInternal(provider: FeatureProvider, initialContext: EvaluationContext? = nil) async {
        await atomicOperationsQueue.run { [self] in
            // Set initial state atomically
            stateQueue.sync {
                self.providerStatus = .notReady
                self.providerSubject.send(provider)
                if let initialContext = initialContext {
                    self.evaluationContext = initialContext
                }
            }

            // Initialize provider - this entire operation is atomic
            do {
                try await provider.initialize(initialContext: initialContext)
                stateQueue.sync {
                    self.providerStatus = .ready
                }
                self.eventHandler.send(.ready(nil))
            } catch {
                stateQueue.sync {
                    switch error {
                    case OpenFeatureError.providerFatalError(_):
                        self.providerStatus = .fatal
                    default:
                        self.providerStatus = .error
                    }
                }
                switch error {
                case OpenFeatureError.providerFatalError(let message):
                    self.eventHandler.send(.error(ProviderEventDetails(message: message, errorCode: .providerFatal)))
                default:
                    self.eventHandler.send(.error(ProviderEventDetails(message: error.localizedDescription)))
                }
            }
        }
    }

    private func updateContext(evaluationContext: EvaluationContext) async {
        await atomicOperationsQueue.run { [self] in
            // Get old context and set new context atomically
            let (oldContext, provider) = stateQueue.sync { () -> (EvaluationContext?, FeatureProvider?) in
                let oldContext = self.evaluationContext
                self.evaluationContext = evaluationContext
                self.providerStatus = .reconciling
                return (oldContext, self.providerSubject.value)
            }

            eventHandler.send(.reconciling(nil))

            // Call provider's onContextSet - this entire operation is atomic
            do {
                try await provider?.onContextSet(
                    oldContext: oldContext,
                    newContext: evaluationContext
                )
                stateQueue.sync {
                    self.providerStatus = .ready
                }
                eventHandler.send(.contextChanged(nil))
            } catch {
                stateQueue.sync {
                    self.providerStatus = .error
                }
                eventHandler.send(.error(ProviderEventDetails(message: error.localizedDescription)))
            }
        }
    }

    struct OpenFeatureState {
        let provider: FeatureProvider?
        let evaluationContext: EvaluationContext?
        let providerStatus: ProviderStatus
    }
}
