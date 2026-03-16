import Combine
import Foundation

/// Tracks individual child provider statuses, computes an aggregate status,
/// and emits aggregate events only when the overall status transitions.
/// Matches the JS SDK's `StatusTracker` pattern.
class MultiProviderStatusTracker {
    private let stateLock = NSLock()
    private let eventSubject: PassthroughSubject<ProviderEvent?, Never>
    private var providerStatuses: [String: ProviderStatus]
    private var lastAggregateStatus: ProviderStatus = .notReady
    private var subscriptions: [AnyCancellable] = []

    init(
        childProviders: [ChildProviderRecord],
        eventSubject: PassthroughSubject<ProviderEvent?, Never>
    ) {
        self.eventSubject = eventSubject
        self.providerStatuses = Dictionary(
            uniqueKeysWithValues: childProviders.map { ($0.name, .notReady) }
        )
        subscribeToProviderEvents(childProviders: childProviders)
    }

    deinit {
        subscriptions.forEach { $0.cancel() }
    }

    func updateStatus(providerName: String, status: ProviderStatus) {
        stateLock.withLock {
            providerStatuses[providerName] = status
            lastAggregateStatus = aggregateProviderStatus()
        }
    }

    func setAllReconciling(childProviders: [ChildProviderRecord]) {
        stateLock.withLock {
            childProviders.forEach {
                providerStatuses[$0.name] = .reconciling
            }
        }
    }

    func statusForError(_ error: Error) -> ProviderStatus {
        switch error {
        case OpenFeatureError.providerFatalError:
            return .fatal
        default:
            return .error
        }
    }

    func activeChildProviders(from childProviders: [ChildProviderRecord]) -> [ChildProviderRecord] {
        stateLock.withLock {
            childProviders.filter { childProvider in
                switch providerStatuses[childProvider.name] ?? .notReady {
                case .ready, .reconciling, .stale:
                    return true
                case .notReady, .error, .fatal:
                    return false
                }
            }
        }
    }

    // MARK: - Private

    private func subscribeToProviderEvents(childProviders: [ChildProviderRecord]) {
        subscriptions = childProviders.map { childProvider in
            childProvider.provider.observe().sink { [weak self] event in
                self?.handleProviderEvent(providerName: childProvider.name, event: event)
            }
        }
    }

    private func handleProviderEvent(providerName: String, event: ProviderEvent?) {
        guard let event else {
            return
        }

        switch event {
        case .ready(let details):
            emitAggregateEvent(for: providerName, status: .ready, details: details)
        case .error(let details):
            emitAggregateEvent(
                for: providerName,
                status: details?.errorCode == .providerFatal ? .fatal : .error,
                details: details
            )
        case .stale(let details):
            emitAggregateEvent(for: providerName, status: .stale, details: details)
        case .reconciling(let details):
            emitAggregateEvent(for: providerName, status: .reconciling, details: details)
        case .configurationChanged(let details):
            eventSubject.send(.configurationChanged(details))
        case .contextChanged(let details):
            eventSubject.send(.contextChanged(details))
        }
    }

    private func emitAggregateEvent(
        for providerName: String,
        status: ProviderStatus,
        details: ProviderEventDetails?
    ) {
        let aggregateEvent: ProviderEvent? = stateLock.withLock {
            providerStatuses[providerName] = status
            let aggregateStatus = aggregateProviderStatus()
            guard aggregateStatus != lastAggregateStatus else {
                return nil
            }

            lastAggregateStatus = aggregateStatus
            return providerEvent(for: aggregateStatus, details: details)
        }

        if let aggregateEvent {
            eventSubject.send(aggregateEvent)
        }
    }

    private func aggregateProviderStatus() -> ProviderStatus {
        providerStatuses.values.max(by: {
            statusPriority(for: $0) < statusPriority(for: $1)
        }) ?? .notReady
    }

    private func statusPriority(for status: ProviderStatus) -> Int {
        switch status {
        case .ready:
            return 0
        case .reconciling:
            return 1
        case .stale:
            return 2
        case .error:
            return 3
        case .notReady:
            return 4
        case .fatal:
            return 5
        }
    }

    private func providerEvent(
        for status: ProviderStatus,
        details: ProviderEventDetails?
    ) -> ProviderEvent? {
        switch status {
        case .ready:
            return .ready(details)
        case .error:
            return .error(details)
        case .fatal:
            return .error(
                ProviderEventDetails(
                    flagsChanged: details?.flagsChanged,
                    message: details?.message,
                    errorCode: details?.errorCode ?? .providerFatal,
                    eventMetadata: details?.eventMetadata ?? [:]
                )
            )
        case .stale:
            return .stale(details)
        case .reconciling:
            return .reconciling(details)
        case .notReady:
            return nil
        }
    }
}
