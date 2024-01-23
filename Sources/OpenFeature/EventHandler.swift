import Foundation
import Combine

public class EventHandler: EventSender, EventPublisher {
    private let eventState: CurrentValueSubject<ProviderEvent, Never>

    public init(_ state: ProviderEvent) {
        eventState = CurrentValueSubject<ProviderEvent, Never>(ProviderEvent.stale)
    }

    public func observe() -> CurrentValueSubject<ProviderEvent, Never> {
        return eventState
    }

    public func send(
        _ event: ProviderEvent
    ) {
        eventState.send(event)
    }
}

public protocol EventPublisher {
    func observe() -> CurrentValueSubject<ProviderEvent, Never>
}

public protocol EventSender {
    func send(_ event: ProviderEvent)
}
