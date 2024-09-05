import Combine
import Foundation

public class EventHandler: EventSender, EventPublisher {
    private let lastSentEvent = PassthroughSubject<ProviderEvent?, Never>()

    public init() {
    }

    public func observe() -> AnyPublisher<ProviderEvent?, Never> {
        return lastSentEvent.eraseToAnyPublisher()
    }

    public func send(
        _ event: ProviderEvent
    ) {
        lastSentEvent.send(event)
    }
}

public protocol EventPublisher {
    func observe() -> AnyPublisher<ProviderEvent?, Never>
}

public protocol EventSender {
    func send(_ event: ProviderEvent)
}
