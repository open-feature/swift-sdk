import Foundation
import OpenFeature
import Combine

class DoSomethingProvider: FeatureProvider {
    public static let name = "Something"
    private let eventHandler = EventHandler()
    private var holdit: AnyCancellable?

    func onContextSet(oldContext: OpenFeature.EvaluationContext?, newContext: OpenFeature.EvaluationContext) {
        eventHandler.emit(.configurationChanged, provider: self)
    }

    func initialize(initialContext: OpenFeature.EvaluationContext?) {
        eventHandler.emit(.ready, provider: self)
    }

    var hooks: [any OpenFeature.Hook] = []
    var metadata: OpenFeature.ProviderMetadata = DoMetadata()

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

    func observe() -> Publishers.MergeMany<NotificationCenter.Publisher> {
        eventHandler.observe()
    }

    public struct DoMetadata: ProviderMetadata {
        public var name: String? = DoSomethingProvider.name
    }
}
