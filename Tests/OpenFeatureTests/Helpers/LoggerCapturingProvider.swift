import Combine
import Foundation
import OpenFeature

/// A provider that records the logger it receives on each evaluation and resolves every flag to its default value.
class LoggerCapturingProvider: FeatureProvider {
    var hooks: [any Hook] = []
    var metadata: ProviderMetadata = TestMetadata()
    /// The logger passed to the most recent logger-enabled evaluation.
    var capturedLogger: (any OpenFeatureLogger)?

    private let statusTracker = ProviderStatusTracker()
    var status: ProviderStatus { statusTracker.status }
    /// Publishes the provider's status events.
    func observe() -> AnyPublisher<ProviderEvent, Never> { statusTracker.observe() }

    /// Immediately reports the provider as ready.
    func initialize(initialContext: EvaluationContext?) -> Future<Void, Never> {
        Future { promise in
            self.statusTracker.send(.ready(nil))
            promise(.success(()))
        }
    }

    /// Accepts any context change without doing work.
    func onContextSet(
        oldContext: EvaluationContext?,
        newContext: EvaluationContext
    ) -> Future<Void, Never> {
        Future { $0(.success(())) }
    }

    /// Resolves to `defaultValue`.
    func getBooleanEvaluation(key: String, defaultValue: Bool, context: EvaluationContext?) throws
        -> ProviderEvaluation<Bool>
    { ProviderEvaluation(value: defaultValue) }

    /// Resolves to `defaultValue`.
    func getStringEvaluation(key: String, defaultValue: String, context: EvaluationContext?) throws
        -> ProviderEvaluation<String>
    { ProviderEvaluation(value: defaultValue) }

    /// Resolves to `defaultValue`.
    func getIntegerEvaluation(key: String, defaultValue: Int64, context: EvaluationContext?) throws
        -> ProviderEvaluation<Int64>
    { ProviderEvaluation(value: defaultValue) }

    /// Resolves to `defaultValue`.
    func getDoubleEvaluation(key: String, defaultValue: Double, context: EvaluationContext?) throws
        -> ProviderEvaluation<Double>
    { ProviderEvaluation(value: defaultValue) }

    /// Resolves to `defaultValue`.
    func getObjectEvaluation(key: String, defaultValue: Value, context: EvaluationContext?) throws
        -> ProviderEvaluation<Value>
    { ProviderEvaluation(value: defaultValue) }

    /// Stores `logger` in ``capturedLogger`` and resolves to `defaultValue`.
    func getBooleanEvaluation(
        key: String, defaultValue: Bool, context: EvaluationContext?, logger: (any OpenFeatureLogger)?
    ) throws
        -> ProviderEvaluation<Bool>
    {
        capturedLogger = logger
        return try getBooleanEvaluation(key: key, defaultValue: defaultValue, context: context)
    }

    /// Stores `logger` in ``capturedLogger`` and resolves to `defaultValue`.
    func getStringEvaluation(
        key: String, defaultValue: String, context: EvaluationContext?, logger: (any OpenFeatureLogger)?
    ) throws
        -> ProviderEvaluation<String>
    {
        capturedLogger = logger
        return try getStringEvaluation(key: key, defaultValue: defaultValue, context: context)
    }

    /// Stores `logger` in ``capturedLogger`` and resolves to `defaultValue`.
    func getIntegerEvaluation(
        key: String, defaultValue: Int64, context: EvaluationContext?, logger: (any OpenFeatureLogger)?
    ) throws
        -> ProviderEvaluation<Int64>
    {
        capturedLogger = logger
        return try getIntegerEvaluation(key: key, defaultValue: defaultValue, context: context)
    }

    /// Stores `logger` in ``capturedLogger`` and resolves to `defaultValue`.
    func getDoubleEvaluation(
        key: String, defaultValue: Double, context: EvaluationContext?, logger: (any OpenFeatureLogger)?
    ) throws
        -> ProviderEvaluation<Double>
    {
        capturedLogger = logger
        return try getDoubleEvaluation(key: key, defaultValue: defaultValue, context: context)
    }

    /// Stores `logger` in ``capturedLogger`` and resolves to `defaultValue`.
    func getObjectEvaluation(
        key: String, defaultValue: Value, context: EvaluationContext?, logger: (any OpenFeatureLogger)?
    ) throws
        -> ProviderEvaluation<Value>
    {
        capturedLogger = logger
        return try getObjectEvaluation(key: key, defaultValue: defaultValue, context: context)
    }

    /// Metadata naming this provider.
    struct TestMetadata: ProviderMetadata { var name: String? = "LoggerCapturingProvider" }
}
