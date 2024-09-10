import Combine
import Foundation

/// A global singleton which holds base configuration for the OpenFeature library.
/// Configuration here will be shared across all ``Client``s.
public class OpenFeatureAPI {
    private var stateManager = SafeStateManager()
    private let eventHandler = EventHandler()
    private(set) var hooks: [any Hook] = []

    /// The ``OpenFeatureAPI`` singleton
    static public let shared = OpenFeatureAPI()

    public init() {
    }

    public func setProvider(provider: FeatureProvider) {
        self.setProvider(provider: provider, initialContext: nil)
    }

    public func setProvider(provider: FeatureProvider, initialContext: EvaluationContext?) {
        stateManager.setProvider(provider: provider, initialContext: initialContext)
        do {
            try provider.initialize(initialContext: initialContext)
            stateManager.update(providerStatus: .ready)
            eventHandler.send(.ready)
        } catch {
            switch error {
            case OpenFeatureError.providerFatalError:
                stateManager.update(providerStatus: .fatal)
                eventHandler.send(.error(errorCode: .providerFatal))
            default:
                stateManager.update(providerStatus: .error)
                eventHandler.send(.error(message: error.localizedDescription))
            }
        }
    }

    public func getProvider() -> FeatureProvider? {
        return self._provider
    }

    public func clearProvider() {
        stateManager.clearProvider()
    }

    public func setEvaluationContext(evaluationContext: EvaluationContext) {
        do {
            let oldContext = self._context
            stateManager.update(evaluationContext: evaluationContext, providerStatus: .reconciling)
            eventHandler.send(.reconciling)
            try getProvider()?.onContextSet(oldContext: oldContext, newContext: evaluationContext)
            stateManager.update(providerStatus: .ready)
            eventHandler.send(.contextChanged)
        } catch {
            stateManager.update(providerStatus: .error)
            eventHandler.send(.error(message: error.localizedDescription))
        }
    }

    public func getEvaluationContext() -> EvaluationContext? {
        return self._context
    }

    public func getProviderStatus() -> ProviderStatus {
        return _providerStatus
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

    public func getState() -> (
        provider: FeatureProvider?, evaluationContext: EvaluationContext?, providerStatus: ProviderStatus
    ) {
        return self.stateManager.getState()
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
}

/// Accessory getters for properties managed in the state manager
extension OpenFeatureAPI {
    private var _provider: FeatureProvider? {
        stateManager.providerSubject.value
    }
    private var _context: EvaluationContext? {
        stateManager.evaluationContext
    }
    private var _providerStatus: ProviderStatus {
        stateManager.providerStatus
    }
    private var providerSubject: CurrentValueSubject<FeatureProvider?, Never> {
        stateManager.providerSubject
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
                setProvider(provider: provider, initialContext: initialContext)
                continuation.resume()
                holder.removeAll()
            }
        }
        await withTaskCancellationHandler {
            await task.value
        } onCancel: {
            task.cancel()
        }
    }
}

/// This helper struct maintains the provider, its state and the global evaluation context
/// It is designed to be thread safe on write: context and status are updated atomically, for example.
/// The allowed bulk-changes are also executed in a serial fashion to guarantee thread-safety.
struct SafeStateManager {
    private let queue = DispatchQueue(label: "com.providerDescriptor.queue")

    private(set) var provider: FeatureProvider?
    private(set) var providerSubject = CurrentValueSubject<FeatureProvider?, Never>(nil)
    private(set) var evaluationContext: EvaluationContext? = nil
    private(set) var providerStatus: ProviderStatus = .notReady

    mutating func setProvider(provider: FeatureProvider, initialContext: EvaluationContext? = nil) {
        queue.sync {
            self.provider = provider
            self.providerStatus = .notReady
            if let initialContext = initialContext {
                self.evaluationContext = initialContext
            }
            providerSubject.send(provider)
        }
    }

    mutating func update(evaluationContext: EvaluationContext? = nil, providerStatus: ProviderStatus? = nil) {
        queue.sync {
            if let newContext = evaluationContext {
                self.evaluationContext = newContext
            }

            if let newStatus = providerStatus {
                self.providerStatus = newStatus
            }
        }
    }

    mutating func clearProvider() {
        queue.sync {
            self.provider = nil
            self.providerSubject.send(nil)
            self.providerStatus = .notReady
        }
    }

    // Method to read all values atomically
    func getState() -> (
        provider: FeatureProvider?, evaluationContext: EvaluationContext?, providerStatus: ProviderStatus
    ) {
        return queue.sync {
            (provider: provider, evaluationContext: evaluationContext, providerStatus: providerStatus)
        }
    }
}
