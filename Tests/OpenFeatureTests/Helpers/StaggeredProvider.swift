import Combine
import Foundation
import OpenFeature

class StaggeredProvider: FeatureProvider {
    public static let name = "Something"
    private let statusTracker = ProviderStatusTracker()
    var status: ProviderStatus { statusTracker.status }
    private let onContextSetSemaphore: DispatchSemaphore?
    public var activeContext: EvaluationContext = MutableContext()

    init(onContextSetSemaphore: DispatchSemaphore?) {
        self.onContextSetSemaphore = onContextSetSemaphore
    }

    func onContextSet(
        oldContext: EvaluationContext?,
        newContext: EvaluationContext
    ) -> Future<Void, Never> {
        return Future { promise in
            self.statusTracker.send(.reconciling(nil))
            self.onContextSetSemaphore?.wait()
            self.activeContext = newContext
            self.statusTracker.send(.contextChanged(nil))
            promise(.success(()))
        }
    }

    func initialize(initialContext: EvaluationContext?) -> Future<Void, Never> {
        return Future { promise in
            if let initialContext {
                self.activeContext = initialContext
            }
            self.statusTracker.send(.ready(nil))
            promise(.success(()))
        }
    }

    var hooks: [any OpenFeature.Hook] = []
    var metadata: OpenFeature.ProviderMetadata = DoMetadata()

    func getBooleanEvaluation(key: String, defaultValue: Bool, context: EvaluationContext?) throws
        -> ProviderEvaluation<
            Bool
        >
    {
        return ProviderEvaluation(value: !defaultValue, flagMetadata: DoSomethingProvider.flagMetadataMap)
    }

    func getStringEvaluation(key: String, defaultValue: String, context: EvaluationContext?) throws
        -> ProviderEvaluation<
            String
        >
    {
        return ProviderEvaluation(
            value: String(defaultValue.reversed()), flagMetadata: DoSomethingProvider.flagMetadataMap)
    }

    func getIntegerEvaluation(key: String, defaultValue: Int64, context: EvaluationContext?) throws
        -> ProviderEvaluation<
            Int64
        >
    {
        return ProviderEvaluation(value: defaultValue * 100, flagMetadata: DoSomethingProvider.flagMetadataMap)
    }

    func getDoubleEvaluation(key: String, defaultValue: Double, context: EvaluationContext?) throws
        -> ProviderEvaluation<
            Double
        >
    {
        return ProviderEvaluation(value: defaultValue * 100, flagMetadata: DoSomethingProvider.flagMetadataMap)
    }

    func getObjectEvaluation(key: String, defaultValue: Value, context: EvaluationContext?) throws
        -> ProviderEvaluation<
            Value
        >
    {
        return ProviderEvaluation(value: .null, flagMetadata: DoSomethingProvider.flagMetadataMap)
    }

    func observe() -> AnyPublisher<ProviderEvent, Never> {
        statusTracker.observe()
    }

    public struct DoMetadata: ProviderMetadata {
        public var name: String? = DoSomethingProvider.name
    }

    public static let flagMetadataMap = [
        "int-metadata": FlagMetadataValue.integer(99),
        "double-metadata": FlagMetadataValue.double(98.4),
        "string-metadata": FlagMetadataValue.string("hello-world"),
        "boolean-metadata": FlagMetadataValue.boolean(true),
    ]
}
