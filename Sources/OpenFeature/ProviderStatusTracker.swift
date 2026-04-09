import Combine
import Foundation

/// Processes ``ProviderEvent``s emitted by a provider, updates ``status`` accordingly,
/// and republishes events to subscribers.
///
/// ## Event to status mapping
///
/// | Event                                          | Resulting status |
/// |------------------------------------------------|------------------|
/// | `.ready`                                       | `.ready`         |
/// | `.error` (recoverable)                         | `.error`         |
/// | `.error(errorCode: .providerFatal)`            | `.fatal`         |
/// | `.stale`                                       | `.stale`         |
/// | `.reconciling`                                 | `.reconciling`   |
/// | `.contextChanged`                              | `.ready`         |
/// | `.configurationChanged`                        | *(no change)*    |
///
/// ## Status replay
///
/// New subscribers automatically receive one synthetic event reflecting the current
/// status, eliminating the race between subscribing and the first live event.
/// No replay is emitted while the provider is in the `.notReady` state.
///
/// ## Recommended usage
///
/// ```swift
/// final class MyProvider: FeatureProvider {
///     private let statusTracker = ProviderStatusTracker()
///
///     var status: ProviderStatus { statusTracker.status }
///     func observe() -> AnyPublisher<ProviderEvent, Never> { statusTracker.observe() }
///
///     func initialize(initialContext: EvaluationContext?) -> Future<Void, Never> {
///         Future { promise in
///             // ... do some work ...
///             self.statusTracker.send(.ready(nil))
///             promise(.success(()))
///         }
///     }
///
///     func onContextSet(oldContext: EvaluationContext?, newContext: EvaluationContext) -> Future<Void, Never> {
///         Future { promise in
///             self.statusTracker.send(.reconciling(nil))
///             // ... do some work ...
///             self.statusTracker.send(.contextChanged(nil))  // or .error(nil)
///             promise(.success(()))
///         }
///     }
/// }
/// ```
public final class ProviderStatusTracker: EventSender, EventPublisher, @unchecked Sendable {
    // MARK: - Locking strategy
    //
    // serializationLock: serializes event handling via send() and protects the critical
    // initial subscription window (reading current status + installing sink atomically),
    // preventing races where a subscriber could miss an event between reading the current
    // status and attaching to the live stream.
    //
    // Per-subscription locks: each TrackerSubscription has its own lock to manage its
    // state (demand, subscriber, cancellation), providing isolation between subscriptions
    // and reducing lock contention.
    //
    // A private TrackerPublisher is used instead of exposing downstreamEvents directly
    // because each subscriber needs to (1) receive a replay event derived from the current
    // status, and (2) atomically transition from that snapshot to live streaming. Both
    // steps happen under serializationLock.
    private let serializationLock = NSLock()

    public init() {}

    // Publishes events for downstream subscribers.
    private let downstreamEvents = PassthroughSubject<ProviderEvent, Never>()
    // Serial queue for executing all subscriber callbacks to avoid
    // send reentrancy and deadlocks.
    private let subscriberQueue = DispatchQueue(label: "dev.openfeature.providerStatusTracker.subscribers")

    // A shorter lock to protect status.
    private let statusLock = NSLock()
    private var _status: ProviderStatus = .notReady
    public private(set) var status: ProviderStatus {
        // Keep status reads/writes lock-protected because evaluation paths may read frequently
        // from threads that do not hold serializationLock.
        get { statusLock.withLock { _status } }
        set { statusLock.withLock { _status = newValue } }
    }

    public func send(_ event: ProviderEvent) {
        serializationLock.withLock {
            handle(event: event)
        }
    }

    public func observe() -> AnyPublisher<ProviderEvent, Never> {
        TrackerPublisher(tracker: self)
            .receive(on: subscriberQueue)
            .eraseToAnyPublisher()
    }

    private func currentStatusEvent() -> ProviderEvent? {
        switch status {
        case .notReady:
            return nil
        case .ready:
            return .ready(nil)
        case .error:
            return .error(nil)
        case .stale:
            return .stale(nil)
        case .fatal:
            return .error(ProviderEventDetails(errorCode: .providerFatal))
        case .reconciling:
            return .reconciling(nil)
        }
    }

    private func handle(event: ProviderEvent) {
        switch event {
        case .ready:
            status = .ready
        case .error(let details) where details?.errorCode == .providerFatal:
            status = .fatal
        case .error:
            status = .error
        case .configurationChanged:
            // No status change.
            break
        case .stale:
            status = .stale
        case .reconciling:
            status = .reconciling
        case .contextChanged:
            status = .ready
        }

        downstreamEvents.send(event)
    }

    private struct TrackerPublisher: Publisher {
        typealias Output = ProviderEvent
        typealias Failure = Never
        let tracker: ProviderStatusTracker

        func receive<S>(subscriber: S) where S: Subscriber, Never == S.Failure, ProviderEvent == S.Input {
            let subscription = TrackerSubscription(subscriber: subscriber, tracker: tracker)
            subscriber.receive(subscription: subscription)
        }
    }

    private final class TrackerSubscription<S: Subscriber>: Subscription
    where S.Input == ProviderEvent, S.Failure == Never {
        private let lock = NSLock()
        private var subscriber: S?
        private weak var tracker: ProviderStatusTracker?
        private var demand: Subscribers.Demand = .none
        private var started = false
        private var downstreamCancellable: AnyCancellable?
        private var isCancelled = false

        init(subscriber: S, tracker: ProviderStatusTracker) {
            self.subscriber = subscriber
            self.tracker = tracker
        }

        func request(_ newDemand: Subscribers.Demand) {
            guard newDemand > .none else { return }
            guard let tracker else { return }

            // Update demand and check if initialization is needed
            let needsInitialization: Bool = lock.withLock {
                guard !isCancelled else { return false }
                demand += newDemand

                if !started {
                    started = true
                    return true
                }
                return false
            }

            guard needsInitialization else { return }

            // Perform initialization:
            // Critical section under serializationLock to prevent missing events
            let sinkCancellable: AnyCancellable? = tracker.serializationLock.withLock {
                // Emit initial event first, then install sink to catch subsequent events
                if let event = tracker.currentStatusEvent() {
                    emit(event)
                }

                return tracker.downstreamEvents.sink { [weak self] event in
                    self?.emit(event)
                }
            }

            // Store cancellable, or cancel immediately if cancelled during init
            var cancellableToCancel: AnyCancellable?
            lock.withLock {
                if isCancelled {
                    cancellableToCancel = sinkCancellable
                } else {
                    downstreamCancellable = sinkCancellable
                }
            }
            cancellableToCancel?.cancel()
        }

        func cancel() {
            var cancellable: AnyCancellable?

            lock.withLock {
                isCancelled = true
                cancellable = downstreamCancellable
                downstreamCancellable = nil
                subscriber = nil
            }

            // Cancel outside lock to avoid holding lock during cleanup
            cancellable?.cancel()
        }

        private func emit(_ event: ProviderEvent) {
            // Check demand and capture subscriber in a single lock acquisition
            let sub: S? = lock.withLock {
                guard let sub = subscriber, demand > .none else { return nil }
                if demand != .unlimited {
                    demand -= 1
                }
                return sub
            }

            guard let sub else { return }

            // Call receive() outside lock to avoid reentrancy deadlock
            let newDemand = sub.receive(event)

            lock.withLock {
                demand += newDemand
            }
        }
    }
}
