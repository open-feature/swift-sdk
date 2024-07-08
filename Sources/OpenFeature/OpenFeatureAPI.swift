import Combine
import Foundation

/// A global singleton which holds base configuration for the OpenFeature library.
/// Configuration here will be shared across all ``Client``s.
public class OpenFeatureAPI {
    private var _provider: FeatureProvider? {
        get {
            providerSubject.value
        }
        set {
            providerSubject.send(newValue)
        }
    }
    private var _context: EvaluationContext?
    private(set) var hooks: [any Hook] = []
    private var providerSubject = CurrentValueSubject<FeatureProvider?, Never>(nil)

    /// The ``OpenFeatureAPI`` singleton
    static public let shared = OpenFeatureAPI()

    public init() {
    }

    public func setProvider(provider: FeatureProvider) {
        self.setProvider(provider: provider, initialContext: nil)
    }

    public func setProvider(provider: FeatureProvider, initialContext: EvaluationContext?) {
        self._provider = provider
        if let context = initialContext {
            self._context = context
        }
        provider.initialize(initialContext: self._context)
    }

    public func getProvider() -> FeatureProvider? {
        return self._provider
    }

    public func clearProvider() {
        self._provider = nil
    }

    public func setEvaluationContext(evaluationContext: EvaluationContext) {
        let oldContext = self._context
        self._context = evaluationContext
        getProvider()?.onContextSet(oldContext: oldContext, newContext: evaluationContext)
    }

    public func getEvaluationContext() -> EvaluationContext? {
        return self._context
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

    public func observe() -> AnyPublisher<ProviderEvent, Never> {
        return providerSubject.map { provider in
            if let provider = provider {
                return provider.observe()
            } else {
                return Empty<ProviderEvent, Never>()
                    .eraseToAnyPublisher()
            }
        }
        .switchToLatest()
        .eraseToAnyPublisher()
    }
}

extension OpenFeatureAPI {
    public func setProviderAndWait(provider: FeatureProvider) async {
        await setProviderAndWait(provider: provider, initialContext: nil)
    }

    public func setProviderAndWait(provider: FeatureProvider, initialContext: EvaluationContext?) async {
        let task = Task {
            var holder: [AnyCancellable] = []
            await withCheckedContinuation { continuation in
                let stateObserver = provider.observe().sink {
                    if $0 == .ready || $0 == .error {
                        continuation.resume()
                        holder.removeAll()
                    }
                }
                stateObserver.store(in: &holder)
                setProvider(provider: provider, initialContext: initialContext)
            }
        }
        await withTaskCancellationHandler {
            await task.value
        } onCancel: {
            task.cancel()
        }
    }
}
