import Combine
import Foundation

/// A ``FeatureProvider`` that resolves flags from an in-memory configuration.
///
/// See the InMemoryProvider section of the README for usage.
public final class InMemoryProvider: FeatureProvider, @unchecked Sendable {
    public static let name = "InMemoryProvider"

    public var hooks: [any Hook] { [] }
    public let metadata: ProviderMetadata = InMemoryProviderMetadata()

    private let statusTracker = ProviderStatusTracker()

    /// Never held while emitting an event: `ProviderStatusTracker.send` takes its own lock and
    /// delivers to subscribers, so a subscriber touching the configuration would deadlock.
    private let flagsLock = NSLock()
    private var _flags: [String: InMemoryFlag]

    public init(flags: [String: InMemoryFlag] = [:]) {
        self._flags = flags
    }

    /// A snapshot of the current flag configuration.
    public var flags: [String: InMemoryFlag] {
        return flagsLock.withLock { _flags }
    }

    public var status: ProviderStatus {
        return statusTracker.status
    }

    public func observe() -> AnyPublisher<ProviderEvent, Never> {
        return statusTracker.observe()
    }

    // MARK: - Lifecycle

    public func initialize(initialContext: EvaluationContext?) -> Future<Void, Never> {
        statusTracker.send(.ready(nil))
        return Future { promise in
            promise(.success(()))
        }
    }

    public func onContextSet(
        oldContext: EvaluationContext?,
        newContext: EvaluationContext
    ) -> Future<Void, Never> {
        // No `.reconciling`: nothing is cached per context, so there is no asynchronous work for
        // it to describe.
        statusTracker.send(.contextChanged(nil))
        return Future { promise in
            promise(.success(()))
        }
    }

    // MARK: - Configuration

    /// Replaces the entire flag configuration, emitting `.configurationChanged` whose
    /// `flagsChanged` is the union of all previous and all new flag keys, per the specification.
    public func putConfiguration(_ flags: [String: InMemoryFlag]) {
        let flagsChanged: [String] = flagsLock.withLock {
            let union = Set(_flags.keys).union(flags.keys)
            _flags = flags
            return union.sorted()
        }
        send(flagsChanged: flagsChanged, message: "flags changed")
    }

    /// Adds or replaces a single flag, emitting `.configurationChanged` for that key.
    public func updateFlag(key: String, flag: InMemoryFlag) {
        flagsLock.withLock { _flags[key] = flag }
        send(flagsChanged: [key], message: "flag added/updated")
    }

    /// Removes a single flag, emitting `.configurationChanged` for that key.
    ///
    /// Nothing is emitted when the flag was not present.
    public func removeFlag(key: String) {
        let existed = flagsLock.withLock { _flags.removeValue(forKey: key) != nil }
        guard existed else { return }
        send(flagsChanged: [key], message: "flag removed")
    }

    private func send(flagsChanged: [String], message: String) {
        statusTracker.send(
            .configurationChanged(
                ProviderEventDetails(flagsChanged: flagsChanged, message: message)))
    }

    // MARK: - Resolution

    public func getBooleanEvaluation(key: String, defaultValue: Bool, context: EvaluationContext?) throws
        -> ProviderEvaluation<Bool>
    {
        return try resolve(key: key, defaultValue: defaultValue, context: context) { $0.asBoolean() }
    }

    public func getStringEvaluation(key: String, defaultValue: String, context: EvaluationContext?) throws
        -> ProviderEvaluation<String>
    {
        return try resolve(key: key, defaultValue: defaultValue, context: context) { $0.asString() }
    }

    public func getIntegerEvaluation(key: String, defaultValue: Int64, context: EvaluationContext?) throws
        -> ProviderEvaluation<Int64>
    {
        return try resolve(key: key, defaultValue: defaultValue, context: context) { $0.asInteger() }
    }

    public func getDoubleEvaluation(key: String, defaultValue: Double, context: EvaluationContext?) throws
        -> ProviderEvaluation<Double>
    {
        return try resolve(key: key, defaultValue: defaultValue, context: context) { $0.asDouble() }
    }

    public func getObjectEvaluation(key: String, defaultValue: Value, context: EvaluationContext?) throws
        -> ProviderEvaluation<Value>
    {
        // Every variant already is a `Value`, so this never reports a type mismatch.
        return try resolve(key: key, defaultValue: defaultValue, context: context) { $0 }
    }

    /// - Parameter coerce: returns `nil` when the stored variant holds a different type.
    private func resolve<T>(
        key: String,
        defaultValue: T,
        context: EvaluationContext?,
        coerce: (Value) -> T?
    ) throws -> ProviderEvaluation<T> {
        // Only `.notReady` blocks evaluation: a transient `.stale` must not turn every
        // resolution into an error.
        guard status != .notReady else {
            throw OpenFeatureError.providerNotReadyError
        }

        guard let flag = flags[key] else {
            throw OpenFeatureError.flagNotFoundError(key: key)
        }

        if flag.disabled {
            return ProviderEvaluation(
                value: defaultValue,
                flagMetadata: flag.flagMetadata,
                reason: Reason.disabled.rawValue)
        }

        let variant: String
        let reason: Reason
        if let contextEvaluator = flag.contextEvaluator {
            if let targeted = contextEvaluator(flag, context) {
                variant = targeted
                reason = .targetingMatch
            } else {
                variant = flag.defaultVariant
                reason = .defaultReason
            }
        } else {
            variant = flag.defaultVariant
            reason = .staticReason
        }

        guard let stored = flag.variants[variant] else {
            throw OpenFeatureError.generalError(
                message: "Flag \"\(key)\" has no variant named \"\(variant)\"")
        }

        guard let value = coerce(stored) else {
            throw OpenFeatureError.typeMismatchError
        }

        return ProviderEvaluation(
            value: value,
            flagMetadata: flag.flagMetadata,
            variant: variant,
            reason: reason.rawValue)
    }
}

extension InMemoryProvider {
    struct InMemoryProviderMetadata: ProviderMetadata {
        var name: String? { InMemoryProvider.name }
    }
}
