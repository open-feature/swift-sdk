import Combine
import Foundation

public class EventHandler: EventSender, EventPublisher {
    private let eventState: CurrentValueSubject<ProviderEvent, Never>

    convenience init() {
        self.init(.notReady)
    }

    public init(_ state: ProviderEvent) {
        eventState = CurrentValueSubject<ProviderEvent, Never>(state)
    }

    public func observe() -> AnyPublisher<ProviderEvent, Never> {
        return eventState.eraseToAnyPublisher()
    }

    public func send(
        _ event: ProviderEvent
    ) {
        eventState.send(event)
    }
}

public protocol EventPublisher {
    func observe() -> AnyPublisher<ProviderEvent, Never>
}

public protocol EventSender {
    func send(_ event: ProviderEvent)
}
