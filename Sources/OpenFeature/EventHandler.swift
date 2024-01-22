import Foundation
import Combine

public class EventHandler: EventEmitter, EventPublisher {
    private let subject: CurrentValueSubject<ProviderEvent, Never>

    public init(_ state: ProviderEvent) {
        subject = CurrentValueSubject<ProviderEvent, Never>(ProviderEvent.stale)
    }

    public func observe() -> CurrentValueSubject<ProviderEvent, Never> {
        return subject
    }

    public func emit(
        _ event: ProviderEvent
    ) {
        subject.send(event)
    }
}

public protocol EventPublisher {
    func observe() -> CurrentValueSubject<ProviderEvent, Never>
}

public protocol EventEmitter {
    func emit(_ event: ProviderEvent)
}
