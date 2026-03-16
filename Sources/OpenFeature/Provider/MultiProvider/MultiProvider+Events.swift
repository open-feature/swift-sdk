import Combine
import Foundation

// MARK: - Event Aggregation & Status Tracking
extension MultiProvider {
    func subscribeToProviderEvents() {
        providerSubscriptions = childProviders.map { childProvider in
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

    func updateProviderStatus(providerName: String, status: ProviderStatus) {
        stateLock.withLock {
            providerStatuses[providerName] = status
            lastAggregateStatus = aggregateProviderStatus()
        }
    }

    func providerStatus(for error: Error) -> ProviderStatus {
        switch error {
        case OpenFeatureError.providerFatalError:
            return .fatal
        default:
            return .error
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

    private func providerEvent(for status: ProviderStatus, details: ProviderEventDetails?) -> ProviderEvent? {
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

    func activeChildProviders() -> [ChildProviderRecord] {
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
}
