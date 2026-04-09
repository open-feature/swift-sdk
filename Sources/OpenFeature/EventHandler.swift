import Combine
import Foundation

public class EventHandler: EventSender, EventPublisher {
    private let events = PassthroughSubject<ProviderEvent, Never>()

    public init() {
    }

    public func observe() -> AnyPublisher<ProviderEvent, Never> {
        return events.eraseToAnyPublisher()
    }

    public func send(
        _ event: ProviderEvent
    ) {
        events.send(event)
    }
}

public protocol EventPublisher {
    func observe() -> AnyPublisher<ProviderEvent, Never>
}

public protocol EventSender {
    func send(_ event: ProviderEvent)
}
