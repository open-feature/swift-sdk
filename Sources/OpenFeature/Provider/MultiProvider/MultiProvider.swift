import Combine
import Foundation
import Logging

private struct childProviderRecord {
    let name: String
    let provider: FeatureProvider
}

private func makeUniqueProviderNames(_ providers: [FeatureProvider]) -> [String] {
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

    private let providers: [FeatureProvider]
    private let childProviders: [childProviderRecord]
    private let strategy: Strategy
    private let hookSupport = HookSupport()
    private let stateQueue = DispatchQueue(label: "com.openfeature.multiprovider.state")
    private let eventSubject = PassthroughSubject<ProviderEvent?, Never>()
    private let logger = Logger(label: "dev.openfeature.multiprovider")
    private var providerStatuses: [String: ProviderStatus]
    private var providerSubscriptions: [AnyCancellable] = []
    private var lastAggregateStatus: ProviderStatus = .notReady

    /// Initialize a MultiProvider with a list of providers and a strategy.
    /// - Parameters:
    ///   - providers: A list of providers to evaluate.
    ///   - strategy: A strategy to evaluate the providers. Defaults to FirstMatchStrategy.
    public init(
        providers: [FeatureProvider],
        strategy: Strategy = FirstMatchStrategy()
    ) {
        let childProviders = zip(providers, makeUniqueProviderNames(providers)).map {
            childProviderRecord(name: $0.1, provider: $0.0)
        }
        self.providers = providers
        self.childProviders = childProviders
        self.strategy = strategy
        self.providerStatuses = Dictionary(uniqueKeysWithValues: childProviders.map { ($0.name, .notReady) })
        metadata = MultiProviderMetadata(providers: childProviders)
        subscribeToProviderEvents()
    }

    deinit {
        providerSubscriptions.forEach { $0.cancel() }
    }

    public func initialize(initialContext: EvaluationContext?) async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            for childProvider in childProviders {
                group.addTask {
                    do {
                        try await childProvider.provider.initialize(initialContext: initialContext)
                        self.updateProviderStatus(providerName: childProvider.name, status: .ready)
                    } catch {
                        self.updateProviderStatus(
                            providerName: childProvider.name,
                            status: self.providerStatus(for: error)
                        )
                        throw error
                    }
                }
            }
            try await group.waitForAll()
        }
    }

    public func onContextSet(oldContext: EvaluationContext?, newContext: EvaluationContext) async throws {
        stateQueue.sync {
            childProviders.forEach {
                providerStatuses[$0.name] = .reconciling
            }
        }

        try await withThrowingTaskGroup(of: Void.self) { group in
            for childProvider in childProviders {
                group.addTask {
                    do {
                        try await childProvider.provider.onContextSet(oldContext: oldContext, newContext: newContext)
                        self.updateProviderStatus(providerName: childProvider.name, status: .ready)
                    } catch {
                        self.updateProviderStatus(providerName: childProvider.name, status: .error)
                        throw error
                    }
                }
            }
            try await group.waitForAll()
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
                try self.evaluateWithProviderHooks(
                    provider: provider,
                    key: key,
                    defaultValue: defaultValue,
                    context: context
                ) {
                    try provider.getBooleanEvaluation(
                        key: key,
                        defaultValue: defaultValue,
                        context: context,
                        logger: logger
                    )
                }
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
                try self.evaluateWithProviderHooks(
                    provider: provider,
                    key: key,
                    defaultValue: defaultValue,
                    context: context
                ) {
                    try provider.getStringEvaluation(
                        key: key,
                        defaultValue: defaultValue,
                        context: context,
                        logger: logger
                    )
                }
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
                try self.evaluateWithProviderHooks(
                    provider: provider,
                    key: key,
                    defaultValue: defaultValue,
                    context: context
                ) {
                    try provider.getIntegerEvaluation(
                        key: key,
                        defaultValue: defaultValue,
                        context: context,
                        logger: logger
                    )
                }
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
                try self.evaluateWithProviderHooks(
                    provider: provider,
                    key: key,
                    defaultValue: defaultValue,
                    context: context
                ) {
                    try provider.getDoubleEvaluation(
                        key: key,
                        defaultValue: defaultValue,
                        context: context,
                        logger: logger
                    )
                }
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
                try self.evaluateWithProviderHooks(
                    provider: provider,
                    key: key,
                    defaultValue: defaultValue,
                    context: context
                ) {
                    try provider.getObjectEvaluation(
                        key: key,
                        defaultValue: defaultValue,
                        context: context,
                        logger: logger
                    )
                }
            }
        }
    }

    public func observe() -> AnyPublisher<ProviderEvent?, Never> {
        eventSubject.eraseToAnyPublisher()
    }

    public func track(key: String, context: (any EvaluationContext)?, details: (any TrackingEventDetails)?) throws {
        for childProvider in activeChildProviders() {
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

        init(providers: [childProviderRecord]) {
            childProviderMetadata = Dictionary(uniqueKeysWithValues: providers.map { ($0.name, $0.provider.metadata) })
            name =
                "MultiProvider: "
                + providers.map {
                    $0.name
                }
                .joined(separator: ", ")
        }
    }
}

extension MultiProvider {
    private func subscribeToProviderEvents() {
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

    private func emitAggregateEvent(for providerName: String, status: ProviderStatus, details: ProviderEventDetails?) {
        let aggregateEvent = stateQueue.sync { () -> ProviderEvent? in
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

    private func updateProviderStatus(providerName: String, status: ProviderStatus) {
        stateQueue.sync {
            providerStatuses[providerName] = status
            lastAggregateStatus = aggregateProviderStatus()
        }
    }

    private func providerStatus(for error: Error) -> ProviderStatus {
        switch error {
        case OpenFeatureError.providerFatalError(_):
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

    private func activeChildProviders() -> [childProviderRecord] {
        stateQueue.sync {
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

    private func evaluateWithProviderHooks<T: AllowedFlagValueType>(
        provider: FeatureProvider,
        key: String,
        defaultValue: T,
        context: EvaluationContext?,
        evaluation: () throws -> ProviderEvaluation<T>
    ) throws -> ProviderEvaluation<T> {
        let providerHooks = provider.hooks
        guard !providerHooks.isEmpty else {
            return try evaluation()
        }

        let hookContext = HookContext(
            flagKey: key,
            type: T.flagValueType,
            defaultValue: defaultValue,
            ctx: context?.deepCopy(),
            clientMetadata: nil,
            providerMetadata: provider.metadata
        )
        let hints: [String: Any] = [:]
        var details = FlagEvaluationDetails(flagKey: key, value: defaultValue)

        hookSupport.beforeHooks(
            flagValueType: T.flagValueType,
            hookCtx: hookContext,
            hooks: providerHooks,
            hints: hints
        )

        defer {
            hookSupport.finallyHooks(
                flagValueType: T.flagValueType,
                hookCtx: hookContext,
                details: details,
                hooks: providerHooks,
                hints: hints
            )
        }

        do {
            let providerEvaluation = try evaluation()
            details = FlagEvaluationDetails.from(providerEval: providerEvaluation, flagKey: key)
            try hookSupport.afterHooks(
                flagValueType: T.flagValueType,
                hookCtx: hookContext,
                details: details,
                hooks: providerHooks,
                hints: hints
            )
            return providerEvaluation
        } catch {
            if let openFeatureError = error as? OpenFeatureError {
                details.errorCode = openFeatureError.errorCode()
            } else if details.errorCode == nil {
                details.errorCode = .general
            }
            details.errorMessage = "\(error)"
            details.reason = Reason.error.rawValue
            hookSupport.errorHooks(
                flagValueType: T.flagValueType,
                hookCtx: hookContext,
                error: error,
                hooks: providerHooks,
                hints: hints
            )
            throw error
        }
    }
}
