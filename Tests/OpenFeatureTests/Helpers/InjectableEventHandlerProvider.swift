import Combine
import Foundation
import OpenFeature

class InjectableEventHandlerProvider: FeatureProvider {
    public static let name = "InjectableEventHandler"
    private let eventHandler: EventHandler

    init(eventHandler: EventHandler) {
        self.eventHandler = eventHandler
    }

    func onContextSet(oldContext: OpenFeature.EvaluationContext?, newContext: OpenFeature.EvaluationContext) {
        // Let the parent test control events via eventHandler
    }

    func initialize(initialContext: OpenFeature.EvaluationContext?) {
        // Let the parent test control events via eventHandler
    }

    var hooks: [any OpenFeature.Hook] = []
    var metadata: OpenFeature.ProviderMetadata = InjectableEventHandlerMetadata()

    func getBooleanEvaluation(key: String, defaultValue: Bool, context: EvaluationContext?) throws
        -> ProviderEvaluation<
            Bool
        >
    {
        return ProviderEvaluation(value: !defaultValue)
    }

    func getStringEvaluation(key: String, defaultValue: String, context: EvaluationContext?) throws
        -> ProviderEvaluation<
            String
        >
    {
        return ProviderEvaluation(value: String(defaultValue.reversed()))
    }

    func getIntegerEvaluation(key: String, defaultValue: Int64, context: EvaluationContext?) throws
        -> ProviderEvaluation<
            Int64
        >
    {
        return ProviderEvaluation(value: defaultValue * 100)
    }

    func getDoubleEvaluation(key: String, defaultValue: Double, context: EvaluationContext?) throws
        -> ProviderEvaluation<
            Double
        >
    {
        return ProviderEvaluation(value: defaultValue * 100)
    }

    func getObjectEvaluation(key: String, defaultValue: Value, context: EvaluationContext?) throws
        -> ProviderEvaluation<
            Value
        >
    {
        return ProviderEvaluation(value: .null)
    }

    func observe() -> AnyPublisher<OpenFeature.ProviderEvent, Never> {
        eventHandler.observe()
    }

    public struct InjectableEventHandlerMetadata: ProviderMetadata {
        public var name: String? = InjectableEventHandlerProvider.name
    }
}
