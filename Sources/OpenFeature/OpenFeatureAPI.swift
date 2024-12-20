import Combine
import Foundation

/// A global singleton which holds base configuration for the OpenFeature library.
/// Configuration here will be shared across all ``Client``s.
public class OpenFeatureAPI {
    private let eventHandler = EventHandler()
    private let queue = DispatchQueue(label: "com.openfeature.providerDescriptor.queue")

    private(set) var providerSubject = CurrentValueSubject<FeatureProvider?, Never>(nil)
    private(set) var evaluationContext: EvaluationContext?
    private(set) var providerStatus: ProviderStatus = .notReady
    private(set) var hooks: [any Hook] = []

    /// The ``OpenFeatureAPI`` singleton
    static public let shared = OpenFeatureAPI()

    public init() {
    }

    /**
    Set provider and calls its `initialize` in a background thread.
    Readiness can be determined from `getState` or listening for `ready` event.
    */
    public func setProvider(provider: FeatureProvider, initialContext: EvaluationContext?) {
        queue.async {
            Task {
                await self.setProviderInternal(provider: provider, initialContext: initialContext)
            }
        }
    }

    /**
    Set provider and calls its `initialize`.
    This async function returns when the `initialize` from the provider is completed.
    */
    public func setProviderAndWait(provider: FeatureProvider, initialContext: EvaluationContext?) async {
        await withCheckedContinuation { continuation in
            queue.async {
                Task {
                    await self.setProviderInternal(provider: provider, initialContext: initialContext)
                    continuation.resume()
                }
            }
        }
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
        queue.sync {
            self.providerSubject.send(nil)
            self.providerStatus = .notReady
        }
    }

    /**
    Set evaluation context and calls the provider's `onContextSet` in a background thread.
    Readiness can be determined from `getState` or listening for `contextChanged` event.
    */
    public func setEvaluationContext(evaluationContext: EvaluationContext) {
        queue.async {
            Task {
                await self.updateContext(evaluationContext: evaluationContext)
            }
        }
    }

    /**
    Set evaluation context and calls the provider's `onContextSet`.
    This async function returns when the `onContextSet` from the provider is completed.
    */
    public func setEvaluationContextAndWait(evaluationContext: EvaluationContext) async {
        await withCheckedContinuation { continuation in
            queue.async {
                Task {
                    await self.updateContext(evaluationContext: evaluationContext)
                    continuation.resume()
                }
            }
        }
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
        return queue.sync {
            OpenFeatureState(
                provider: providerSubject.value,
                evaluationContext: evaluationContext,
                providerStatus: providerStatus)
        }
    }

    private func setProviderInternal(provider: FeatureProvider, initialContext: EvaluationContext? = nil) async {
        self.providerStatus = .notReady
        self.providerSubject.send(provider)

        if let initialContext = initialContext {
            self.evaluationContext = initialContext
        }

        do {
            try await provider.initialize(initialContext: initialContext)
            self.providerStatus = .ready
            self.eventHandler.send(.ready)
        } catch {
            switch error {
            case OpenFeatureError.providerFatalError:
                self.providerStatus = .fatal
                self.eventHandler.send(.error(errorCode: .providerFatal))
            default:
                self.providerStatus = .error
                self.eventHandler.send(.error(message: error.localizedDescription))
            }
        }
    }

    private func updateContext(evaluationContext: EvaluationContext) async {
        do {
            let oldContext = self.evaluationContext
            self.evaluationContext = evaluationContext
            self.providerStatus = .reconciling
            eventHandler.send(.reconciling)
            try await self.providerSubject.value?.onContextSet(oldContext: oldContext, newContext: evaluationContext)
            self.providerStatus = .ready
            eventHandler.send(.contextChanged)
        } catch {
            self.providerStatus = .error
            eventHandler.send(.error(message: error.localizedDescription))
        }
    }

    struct OpenFeatureState {
        let provider: FeatureProvider?
        let evaluationContext: EvaluationContext?
        let providerStatus: ProviderStatus
    }
}
