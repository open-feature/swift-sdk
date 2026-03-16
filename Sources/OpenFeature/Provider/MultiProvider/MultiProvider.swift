import Combine
import Foundation
import Logging

/// Error thrown when one or more child providers fail during initialization or context change.
/// Collects all errors from all providers, matching the JS SDK's AggregateError pattern.
public struct MultiProviderAggregateError: Error, LocalizedError {
    public let providerErrors: [(providerName: String, error: Error)]

    public var errorDescription: String? {
        let messages = providerErrors.map { "\($0.providerName): \($0.error)" }
        return "MultiProvider encountered errors from providers: \(messages.joined(separator: ", "))"
    }
}

struct ChildProviderRecord {
    let name: String
    let provider: FeatureProvider
}

/// Generates unique names for a list of providers by appending `-1`, `-2`, etc. when there are
/// name collisions. Providers with unique names keep their bare name. Matches the JS SDK's
/// `registerProviders` name deduplication logic.
func makeUniqueProviderNames(_ providers: [FeatureProvider]) -> [String] {
    let baseNames = providers.map { $0.metadata.name ?? "Provider" }
    var totalCounts: [String: Int] = [:]
    baseNames.forEach { baseName in
        totalCounts[baseName, default: 0] += 1
    }

    var seenCounts: [String: Int] = [:]
    return baseNames.map { baseName in
        guard totalCounts[baseName, default: 0] > 1 else {
            return baseName
        }

        seenCounts[baseName, default: 0] += 1
        return "\(baseName)-\(seenCounts[baseName, default: 0])"
    }
}

/// A provider that combines multiple providers into a single provider.
public class MultiProvider: FeatureProvider {
    public var hooks: [any Hook] {
        []
    }

    public static let name = "MultiProvider"
    public var metadata: ProviderMetadata

    let providers: [FeatureProvider]
    let childProviders: [ChildProviderRecord]
    let strategy: Strategy
    let hookSupport = HookSupport()
    let eventSubject = PassthroughSubject<ProviderEvent?, Never>()
    let logger = Logger(label: "dev.openfeature.multiprovider")
    let statusTracker: MultiProviderStatusTracker

    /// Initialize a MultiProvider with a list of providers and a strategy.
    /// - Parameters:
    ///   - providers: A list of providers to evaluate.
    ///   - strategy: A strategy to evaluate the providers. Defaults to FirstMatchStrategy.
    public init(
        providers: [FeatureProvider],
        strategy: Strategy = FirstMatchStrategy()
    ) {
        let childProviders = zip(providers, makeUniqueProviderNames(providers)).map {
            ChildProviderRecord(name: $0.1, provider: $0.0)
        }
        self.providers = providers
        self.childProviders = childProviders
        self.strategy = strategy
        self.statusTracker = MultiProviderStatusTracker(
            childProviders: childProviders,
            eventSubject: eventSubject
        )
        metadata = MultiProviderMetadata(providers: childProviders)
    }

    public func initialize(initialContext: EvaluationContext?) async throws {
        let errors: [(providerName: String, error: Error)] = await withTaskGroup(
            of: (String, Error?).self
        ) { group in
            for childProvider in childProviders {
                group.addTask {
                    do {
                        try await childProvider.provider.initialize(initialContext: initialContext)
                        self.statusTracker.updateStatus(
                            providerName: childProvider.name, status: .ready)
                        return (childProvider.name, nil)
                    } catch {
                        self.statusTracker.updateStatus(
                            providerName: childProvider.name,
                            status: self.statusTracker.statusForError(error)
                        )
                        return (childProvider.name, error)
                    }
                }
            }

            var errors: [(providerName: String, error: Error)] = []
            for await (name, error) in group {
                if let error {
                    errors.append((providerName: name, error: error))
                }
            }
            return errors
        }

        if !errors.isEmpty {
            throw MultiProviderAggregateError(providerErrors: errors)
        }
    }

    public func onContextSet(
        oldContext: EvaluationContext?,
        newContext: EvaluationContext
    ) async throws {
        statusTracker.setAllReconciling(childProviders: childProviders)

        let errors: [(providerName: String, error: Error)] = await withTaskGroup(
            of: (String, Error?).self
        ) { group in
            for childProvider in childProviders {
                group.addTask {
                    do {
                        try await childProvider.provider.onContextSet(
                            oldContext: oldContext, newContext: newContext)
                        self.statusTracker.updateStatus(
                            providerName: childProvider.name, status: .ready)
                        return (childProvider.name, nil)
                    } catch {
                        self.statusTracker.updateStatus(
                            providerName: childProvider.name,
                            status: self.statusTracker.statusForError(error)
                        )
                        return (childProvider.name, error)
                    }
                }
            }

            var errors: [(providerName: String, error: Error)] = []
            for await (name, error) in group {
                if let error {
                    errors.append((providerName: name, error: error))
                }
            }
            return errors
        }

        if !errors.isEmpty {
            throw MultiProviderAggregateError(providerErrors: errors)
        }
    }

    public func getBooleanEvaluation(
        key: String,
        defaultValue: Bool,
        context: EvaluationContext?
    ) throws -> ProviderEvaluation<Bool> {
        try getBooleanEvaluation(
            key: key, defaultValue: defaultValue, context: context, logger: nil)
    }

    public func getStringEvaluation(
        key: String,
        defaultValue: String,
        context: EvaluationContext?
    ) throws -> ProviderEvaluation<String> {
        try getStringEvaluation(
            key: key, defaultValue: defaultValue, context: context, logger: nil)
    }

    public func getIntegerEvaluation(
        key: String,
        defaultValue: Int64,
        context: EvaluationContext?
    ) throws -> ProviderEvaluation<Int64> {
        try getIntegerEvaluation(
            key: key, defaultValue: defaultValue, context: context, logger: nil)
    }

    public func getDoubleEvaluation(
        key: String,
        defaultValue: Double,
        context: EvaluationContext?
    ) throws -> ProviderEvaluation<Double> {
        try getDoubleEvaluation(
            key: key, defaultValue: defaultValue, context: context, logger: nil)
    }

    public func getObjectEvaluation(
        key: String,
        defaultValue: Value,
        context: EvaluationContext?
    ) throws -> ProviderEvaluation<Value> {
        try getObjectEvaluation(
            key: key, defaultValue: defaultValue, context: context, logger: nil)
    }

    public func observe() -> AnyPublisher<ProviderEvent?, Never> {
        eventSubject.eraseToAnyPublisher()
    }

    public func track(
        key: String,
        context: (any EvaluationContext)?,
        details: (any TrackingEventDetails)?
    ) throws {
        for childProvider in statusTracker.activeChildProviders(from: childProviders) {
            do {
                try childProvider.provider.track(key: key, context: context, details: details)
            } catch {
                logger.error(
                    "Unable to report track event with key \(key) for child provider \(childProvider.name) due to exception \(String(describing: error))"
                )
            }
        }
    }

    public struct MultiProviderMetadata: ProviderMetadata {
        public var name: String?
        public let childProviderMetadata: [String: any ProviderMetadata]

        init(providers: [ChildProviderRecord]) {
            childProviderMetadata = Dictionary(
                uniqueKeysWithValues: providers.map { ($0.name, $0.provider.metadata) }
            )
            name =
                "MultiProvider: "
                + providers.map { $0.name }
                .joined(separator: ", ")
        }
    }
}
