import Foundation

/// A global singleton which holds base configuration for the OpenFeature library.
/// Configuration here will be shared across all ``Client``s.
public class OpenFeatureAPI {
    private var _provider: FeatureProvider?
    private var _context: EvaluationContext?
    private(set) var hooks: [any Hook] = []

    private let providerNotificationCentre = NotificationCenter()

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
}

// MARK: Provider Events

extension OpenFeatureAPI {
    public func addHandler(observer: Any, selector: Selector, event: ProviderEvent) {
        providerNotificationCentre.addObserver(
            observer,
            selector: selector,
            name: event.notification,
            object: nil
        )
    }

    public func removeHandler(observer: Any, event: ProviderEvent) {
        providerNotificationCentre.removeObserver(observer, name: event.notification, object: nil)
    }

    public func emitEvent(
        _ event: ProviderEvent,
        provider: FeatureProvider,
        error: Error? = nil,
        details: [AnyHashable: Any]? = nil
    ) {
        var userInfo: [AnyHashable: Any] = [:]
        userInfo[providerEventDetailsKeyProvider] = provider

        if let error {
            userInfo[providerEventDetailsKeyError] = error
        }

        if let details {
            userInfo.merge(details) { $1 } // Merge, keeping value from `details` if any conflicts
        }

        providerNotificationCentre.post(name: event.notification, object: nil, userInfo: userInfo)
    }
}
