import Combine
import Foundation
import OpenFeature

/// A provider that captures the logger it receives for testing
class LoggerCapturingProvider: FeatureProvider {
    var hooks: [any Hook] = []
    var metadata: ProviderMetadata = TestMetadata()
    var capturedLogger: (any OpenFeatureLogger)?

    private let statusTracker = ProviderStatusTracker()
    var status: ProviderStatus { statusTracker.status }
    func observe() -> AnyPublisher<ProviderEvent, Never> { statusTracker.observe() }

    func initialize(initialContext: EvaluationContext?) -> Future<Void, Never> {
        Future { promise in
            self.statusTracker.send(.ready(nil))
            promise(.success(()))
        }
    }

    func onContextSet(
        oldContext: EvaluationContext?,
        newContext: EvaluationContext
    ) -> Future<Void, Never> {
        Future { $0(.success(())) }
    }

    func getBooleanEvaluation(key: String, defaultValue: Bool, context: EvaluationContext?) throws
        -> ProviderEvaluation<Bool>
    { ProviderEvaluation(value: defaultValue) }

    func getStringEvaluation(key: String, defaultValue: String, context: EvaluationContext?) throws
        -> ProviderEvaluation<String>
    { ProviderEvaluation(value: defaultValue) }

    func getIntegerEvaluation(key: String, defaultValue: Int64, context: EvaluationContext?) throws
        -> ProviderEvaluation<Int64>
    { ProviderEvaluation(value: defaultValue) }

    func getDoubleEvaluation(key: String, defaultValue: Double, context: EvaluationContext?) throws
        -> ProviderEvaluation<Double>
    { ProviderEvaluation(value: defaultValue) }

    func getObjectEvaluation(key: String, defaultValue: Value, context: EvaluationContext?) throws
        -> ProviderEvaluation<Value>
    { ProviderEvaluation(value: defaultValue) }

    // Logger-enabled overrides that capture the logger
    func getBooleanEvaluation(
        key: String, defaultValue: Bool, context: EvaluationContext?, logger: (any OpenFeatureLogger)?
    ) throws
        -> ProviderEvaluation<Bool>
    {
        capturedLogger = logger
        return try getBooleanEvaluation(key: key, defaultValue: defaultValue, context: context)
    }

    func getStringEvaluation(
        key: String, defaultValue: String, context: EvaluationContext?, logger: (any OpenFeatureLogger)?
    ) throws
        -> ProviderEvaluation<String>
    {
        capturedLogger = logger
        return try getStringEvaluation(key: key, defaultValue: defaultValue, context: context)
    }

    func getIntegerEvaluation(
        key: String, defaultValue: Int64, context: EvaluationContext?, logger: (any OpenFeatureLogger)?
    ) throws
        -> ProviderEvaluation<Int64>
    {
        capturedLogger = logger
        return try getIntegerEvaluation(key: key, defaultValue: defaultValue, context: context)
    }

    func getDoubleEvaluation(
        key: String, defaultValue: Double, context: EvaluationContext?, logger: (any OpenFeatureLogger)?
    ) throws
        -> ProviderEvaluation<Double>
    {
        capturedLogger = logger
        return try getDoubleEvaluation(key: key, defaultValue: defaultValue, context: context)
    }

    func getObjectEvaluation(
        key: String, defaultValue: Value, context: EvaluationContext?, logger: (any OpenFeatureLogger)?
    ) throws
        -> ProviderEvaluation<Value>
    {
        capturedLogger = logger
        return try getObjectEvaluation(key: key, defaultValue: defaultValue, context: context)
    }

    struct TestMetadata: ProviderMetadata { var name: String? = "LoggerCapturingProvider" }
}
