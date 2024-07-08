import Combine
import Foundation
import OpenFeature

class DoSomethingProvider: FeatureProvider {
    public static let name = "Something"
    private let eventHandler = EventHandler(.notReady)
    private var holdit: AnyCancellable?

    func onContextSet(oldContext: OpenFeature.EvaluationContext?, newContext: OpenFeature.EvaluationContext) {
        eventHandler.send(.ready)
    }

    func initialize(initialContext: OpenFeature.EvaluationContext?) {
        eventHandler.send(.ready)
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
        eventHandler.observe()
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
