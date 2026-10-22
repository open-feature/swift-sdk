import Combine
import Foundation

/// A provider that combines multiple providers into a single provider.
public class MultiProvider: FeatureProvider {
    public var hooks: [any Hook] {
        []
    }

    public static let name = "MultiProvider"
    public var metadata: ProviderMetadata

    private let providers: [FeatureProvider]
    private let strategy: Strategy
    private let logger: (any OpenFeatureLogger)?

    private let statusTracker = ProviderStatusTracker()
    public var status: ProviderStatus { statusTracker.status }

    /// Decides which lifecycle call may change the status. `initialize` and `shutdown` each start a new generation;
    /// an `initialize`, `onContextSet` or `shutdown` changes the status only while the generation it started in is
    /// still current, so a call overtaken by a later `initialize` or `shutdown` leaves the status alone. The check
    /// and the change happen together under `lifecycleLock`. Holding it across `statusTracker.send` is safe because
    /// the tracker delivers events to subscribers asynchronously.
    private let lifecycleLock = NSLock()
    private var generation = 0

    /// Initialize a MultiProvider with a list of providers and a strategy.
    /// - Parameters:
    ///   - providers: A list of providers to evaluate.
    ///   - strategy: A strategy to evaluate the providers. Defaults to FirstMatchStrategy.
    ///   - logger: Logger used by the MultiProvider itself, e.g. to report errors from child providers while
    ///     tracking. It is not passed to child providers; they receive the logger resolved for each evaluation.
    public init(
        providers: [FeatureProvider],
        strategy: Strategy = FirstMatchStrategy(),
        logger: (any OpenFeatureLogger)? = nil
    ) {
        self.providers = providers
        self.strategy = strategy
        self.logger = logger
        metadata = MultiProviderMetadata(providers: providers)
    }

    public func initialize(initialContext: EvaluationContext?) -> Future<Void, Never> {
        let started = startGeneration()
        let futures = providers.map { $0.initialize(initialContext: initialContext) }
        return Future { promise in
            afterAll(futures) {
                self.ifCurrent(started) { self.updateStatus() }
                promise(.success(()))
            }
        }
    }

    public func onContextSet(
        oldContext: EvaluationContext?,
        newContext: EvaluationContext
    ) -> Future<Void, Never> {
        let started = currentGeneration()
        let futures = providers.map { $0.onContextSet(oldContext: oldContext, newContext: newContext) }
        return Future { promise in
            self.ifCurrent(started) { self.statusTracker.send(.reconciling()) }
            afterAll(futures) {
                self.ifCurrent(started) { self.updateStatus() }
                promise(.success(()))
            }
        }
    }

    /// Shuts down every child provider, waits for all of them to finish, then reverts to `.notReady`.
    /// `initialize` or `onContextSet` calls still in flight no longer update the status, and an `initialize` that
    /// arrives before the children finish takes over, so the reset is skipped. Calling it again shuts the children
    /// down again, so it is only as repeat-safe as they are.
    public func shutdown() -> Future<Void, Never> {
        let started = startGeneration()
        let futures = providers.map { $0.shutdown() }
        return Future { promise in
            afterAll(futures) {
                self.ifCurrent(started) { self.statusTracker.reset() }
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

    /// Evaluates a boolean flag across the child providers using the configured strategy.
    ///
    /// This is the canonical implementation; the logger-less overload delegates here with a `nil` logger.
    /// - Parameters:
    ///   - key: The flag key.
    ///   - defaultValue: The value returned when no provider resolves the flag.
    ///   - context: The evaluation context.
    ///   - logger: The logger resolved for this evaluation, forwarded to every child provider.
    /// - Returns: The evaluation selected by the strategy.
    /// - Throws: Any error the strategy propagates from the child providers.
    public func getBooleanEvaluation(
        key: String, defaultValue: Bool, context: EvaluationContext?, logger: (any OpenFeatureLogger)?
    )
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

    /// Evaluates a string flag across the child providers using the configured strategy.
    ///
    /// This is the canonical implementation; the logger-less overload delegates here with a `nil` logger.
    /// - Parameters:
    ///   - key: The flag key.
    ///   - defaultValue: The value returned when no provider resolves the flag.
    ///   - context: The evaluation context.
    ///   - logger: The logger resolved for this evaluation, forwarded to every child provider.
    /// - Returns: The evaluation selected by the strategy.
    /// - Throws: Any error the strategy propagates from the child providers.
    public func getStringEvaluation(
        key: String, defaultValue: String, context: EvaluationContext?, logger: (any OpenFeatureLogger)?
    )
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

    /// Evaluates an integer flag across the child providers using the configured strategy.
    ///
    /// This is the canonical implementation; the logger-less overload delegates here with a `nil` logger.
    /// - Parameters:
    ///   - key: The flag key.
    ///   - defaultValue: The value returned when no provider resolves the flag.
    ///   - context: The evaluation context.
    ///   - logger: The logger resolved for this evaluation, forwarded to every child provider.
    /// - Returns: The evaluation selected by the strategy.
    /// - Throws: Any error the strategy propagates from the child providers.
    public func getIntegerEvaluation(
        key: String, defaultValue: Int64, context: EvaluationContext?, logger: (any OpenFeatureLogger)?
    )
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

    /// Evaluates a double flag across the child providers using the configured strategy.
    ///
    /// This is the canonical implementation; the logger-less overload delegates here with a `nil` logger.
    /// - Parameters:
    ///   - key: The flag key.
    ///   - defaultValue: The value returned when no provider resolves the flag.
    ///   - context: The evaluation context.
    ///   - logger: The logger resolved for this evaluation, forwarded to every child provider.
    /// - Returns: The evaluation selected by the strategy.
    /// - Throws: Any error the strategy propagates from the child providers.
    public func getDoubleEvaluation(
        key: String, defaultValue: Double, context: EvaluationContext?, logger: (any OpenFeatureLogger)?
    )
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

    /// Evaluates an object flag across the child providers using the configured strategy.
    ///
    /// This is the canonical implementation; the logger-less overload delegates here with a `nil` logger.
    /// - Parameters:
    ///   - key: The flag key.
    ///   - defaultValue: The value returned when no provider resolves the flag.
    ///   - context: The evaluation context.
    ///   - logger: The logger resolved for this evaluation, forwarded to every child provider.
    /// - Returns: The evaluation selected by the strategy.
    /// - Throws: Any error the strategy propagates from the child providers.
    public func getObjectEvaluation(
        key: String, defaultValue: Value, context: EvaluationContext?, logger: (any OpenFeatureLogger)?
    )
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

    /// Starts a new generation, invalidating every lifecycle call still in flight, and returns it.
    private func startGeneration() -> Int {
        lifecycleLock.withLock {
            generation += 1
            return generation
        }
    }

    private func currentGeneration() -> Int {
        lifecycleLock.withLock { generation }
    }

    /// Runs `change` unless `initialize` or `shutdown` has started a new generation since `started`.
    private func ifCurrent(_ started: Int, _ change: () -> Void) {
        lifecycleLock.withLock {
            if generation == started {
                change()
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
