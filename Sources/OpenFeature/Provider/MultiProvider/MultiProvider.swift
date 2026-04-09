import Combine
import Foundation
import Logging

/// A provider that combines multiple providers into a single provider.
public class MultiProvider: FeatureProvider {
    public var hooks: [any Hook] {
        []
    }

    public static let name = "MultiProvider"
    public var metadata: ProviderMetadata

    private let providers: [FeatureProvider]
    private let strategy: Strategy
    private let logger: Logger?

    private let statusTracker = ProviderStatusTracker()
    public var status: ProviderStatus { statusTracker.status }

    /// Initialize a MultiProvider with a list of providers and a strategy.
    /// - Parameters:
    ///   - providers: A list of providers to evaluate.
    ///   - strategy: A strategy to evaluate the providers. Defaults to FirstMatchStrategy.
    public init(
        providers: [FeatureProvider],
        strategy: Strategy = FirstMatchStrategy(),
        logger: Logger? = nil
    ) {
        self.providers = providers
        self.strategy = strategy
        self.logger = logger
        metadata = MultiProviderMetadata(providers: providers)
    }

    public func initialize(initialContext: EvaluationContext?) -> Future<Void, Never> {
        let futures = providers.map { $0.initialize(initialContext: initialContext) }
        return Future { promise in
            afterAll(futures) {
                self.updateStatus()
                promise(.success(()))
            }
        }
    }

    public func onContextSet(
        oldContext: EvaluationContext?,
        newContext: EvaluationContext
    ) -> Future<Void, Never> {
        let futures = providers.map { $0.onContextSet(oldContext: oldContext, newContext: newContext) }
        return Future { promise in
            self.statusTracker.send(.reconciling())
            afterAll(futures) {
                self.updateStatus()
                promise(.success(()))
            }
        }
    }

    public func getBooleanEvaluation(key: String, defaultValue: Bool, context: EvaluationContext?) throws
        -> ProviderEvaluation<Bool>
    {
        return try getBooleanEvaluation(key: key, defaultValue: defaultValue, context: context, logger: nil)
    }

    public func getStringEvaluation(key: String, defaultValue: String, context: EvaluationContext?) throws
        -> ProviderEvaluation<String>
    {
        return try getStringEvaluation(key: key, defaultValue: defaultValue, context: context, logger: nil)
    }

    public func getIntegerEvaluation(key: String, defaultValue: Int64, context: EvaluationContext?) throws
        -> ProviderEvaluation<Int64>
    {
        return try getIntegerEvaluation(key: key, defaultValue: defaultValue, context: context, logger: nil)
    }

    public func getDoubleEvaluation(key: String, defaultValue: Double, context: EvaluationContext?) throws
        -> ProviderEvaluation<Double>
    {
        return try getDoubleEvaluation(key: key, defaultValue: defaultValue, context: context, logger: nil)
    }

    public func getObjectEvaluation(key: String, defaultValue: Value, context: EvaluationContext?) throws
        -> ProviderEvaluation<Value>
    {
        return try getObjectEvaluation(key: key, defaultValue: defaultValue, context: context, logger: nil)
    }

    // Logger-enabled methods - canonical implementations
    public func getBooleanEvaluation(key: String, defaultValue: Bool, context: EvaluationContext?, logger: Logger?)
        throws
        -> ProviderEvaluation<Bool>
    {
        return try strategy.evaluate(
            providers: providers,
            key: key,
            defaultValue: defaultValue,
            evaluationContext: context
        ) { provider in
            { (key: String, defaultValue: Bool, context: EvaluationContext?) throws -> ProviderEvaluation<Bool> in
                try provider.getBooleanEvaluation(
                    key: key, defaultValue: defaultValue, context: context, logger: logger)
            }
        }
    }

    public func getStringEvaluation(key: String, defaultValue: String, context: EvaluationContext?, logger: Logger?)
        throws
        -> ProviderEvaluation<String>
    {
        return try strategy.evaluate(
            providers: providers,
            key: key,
            defaultValue: defaultValue,
            evaluationContext: context
        ) { provider in
            { (key: String, defaultValue: String, context: EvaluationContext?) throws -> ProviderEvaluation<String> in
                try provider.getStringEvaluation(key: key, defaultValue: defaultValue, context: context, logger: logger)
            }
        }
    }

    public func getIntegerEvaluation(key: String, defaultValue: Int64, context: EvaluationContext?, logger: Logger?)
        throws
        -> ProviderEvaluation<Int64>
    {
        return try strategy.evaluate(
            providers: providers,
            key: key,
            defaultValue: defaultValue,
            evaluationContext: context
        ) { provider in
            { (key: String, defaultValue: Int64, context: EvaluationContext?) throws -> ProviderEvaluation<Int64> in
                try provider.getIntegerEvaluation(
                    key: key, defaultValue: defaultValue, context: context, logger: logger)
            }
        }
    }

    public func getDoubleEvaluation(key: String, defaultValue: Double, context: EvaluationContext?, logger: Logger?)
        throws
        -> ProviderEvaluation<Double>
    {
        return try strategy.evaluate(
            providers: providers,
            key: key,
            defaultValue: defaultValue,
            evaluationContext: context
        ) { provider in
            { (key: String, defaultValue: Double, context: EvaluationContext?) throws -> ProviderEvaluation<Double> in
                try provider.getDoubleEvaluation(key: key, defaultValue: defaultValue, context: context, logger: logger)
            }
        }
    }

    public func getObjectEvaluation(key: String, defaultValue: Value, context: EvaluationContext?, logger: Logger?)
        throws
        -> ProviderEvaluation<Value>
    {
        return try strategy.evaluate(
            providers: providers,
            key: key,
            defaultValue: defaultValue,
            evaluationContext: context
        ) { provider in
            { (key: String, defaultValue: Value, context: EvaluationContext?) throws -> ProviderEvaluation<Value> in
                try provider.getObjectEvaluation(key: key, defaultValue: defaultValue, context: context, logger: logger)
            }
        }
    }

    private func updateStatus() {
        let event: ProviderEvent? =
            switch (statusTracker.status, strategy.status(providers: providers)) {
            case (_, .notReady): nil  // no "not ready" event to emit
            case (.reconciling, .ready): .contextChanged()
            case (_, .ready): .ready()
            case (_, .error): .error()
            case (_, .fatal): .error(ProviderEventDetails(errorCode: ErrorCode.providerFatal))
            case (_, .stale): .stale()
            case (_, .reconciling): .reconciling()
            }
        if let event {
            statusTracker.send(event)
        }
    }

    public func track(key: String, context: (any EvaluationContext)?, details: (any TrackingEventDetails)?) throws {
        for provider in providers {
            do {
                try provider.track(key: key, context: context, details: details)
            } catch {
                let providerName = provider.metadata.name ?? "Provider"
                logger?.error(
                    "Error tracking event \"\(key)\" with provider \"\(providerName)\": \(error)"
                )
            }
        }
    }

    public func observe() -> AnyPublisher<ProviderEvent, Never> {
        let providerPublishers = providers.map { $0.observe() }
        return Publishers.MergeMany([statusTracker.observe()] + providerPublishers).eraseToAnyPublisher()
    }

    public struct MultiProviderMetadata: ProviderMetadata {
        public var name: String?

        init(providers: [FeatureProvider]) {
            name =
                "MultiProvider: "
                + providers.map {
                    $0.metadata.name ?? "Provider"
                }
                .joined(separator: ", ")
        }
    }
}

/// Waits for all futures to complete, then calls the completion handler.
private func afterAll(
    _ futures: [Future<Void, Never>],
    then completion: @escaping @Sendable () -> Void
) {
    let group = DispatchGroup()
    var cancellables: [AnyCancellable] = []

    for future in futures {
        group.enter()
        let cancellable = future.sink { _ in
            group.leave()
        }
        cancellables.append(cancellable)
    }

    group.notify(queue: .global()) {
        withExtendedLifetime(cancellables) {}
        completion()
    }
}
