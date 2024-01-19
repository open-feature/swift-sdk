import Foundation
import Combine

public class EventHandler: EventEmitter, EventPublisher {
    private let providerNotificationCentre = NotificationCenter()

    public init() {
    }

    public func observe() -> Publishers.MergeMany<NotificationCenter.Publisher> {
        // TODO Use sealed enum to ensure completeness
        providerNotificationCentre.publisher(for: ProviderEvent.ready.notificationName)
            .merge(with: providerNotificationCentre.publisher(for: ProviderEvent.error.notificationName))
            .merge(with: providerNotificationCentre.publisher(for: ProviderEvent.stale.notificationName))
            .merge(with: providerNotificationCentre.publisher(for: ProviderEvent.configurationChanged.notificationName))
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

        providerNotificationCentre.post(name: event.notificationName, object: nil, userInfo: userInfo)
    }
}

public protocol EventPublisher {
    func observe() -> Publishers.MergeMany<NotificationCenter.Publisher>
}

public protocol EventEmitter {
    func emit(_ event: ProviderEvent, provider: FeatureProvider, error: Error?, details: [AnyHashable: Any]?)
}
