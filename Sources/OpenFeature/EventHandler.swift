import Foundation

public class EventHandler: EventEmitter, EventPublisher {
    private let providerNotificationCentre = NotificationCenter()

    public init() {
    }

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

    public func emit(
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

public protocol EventPublisher {
    func addHandler(observer: Any, selector: Selector, event: ProviderEvent)
    func removeHandler(observer: Any, event: ProviderEvent)
}

public protocol EventEmitter {
    func emit(_ event: ProviderEvent, provider: FeatureProvider, error: Error?, details: [AnyHashable: Any]?)
}
