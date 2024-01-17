import Foundation
import OpenFeature

class DoSomethingProvider: FeatureProvider {
    public static let name = "Something"
    private var ready = false

    func onContextSet(oldContext: OpenFeature.EvaluationContext?, newContext: OpenFeature.EvaluationContext) {
        OpenFeatureAPI.shared.emitEvent(.configurationChanged, provider: self)
    }

    func initialize(initialContext: OpenFeature.EvaluationContext?) {
        Task {
            print(">> Starting")
            try! await Task.sleep(nanoseconds: 1 * 1000000)
            print(">> Done")
            self.ready = true
            OpenFeatureAPI.shared.emitEvent(.ready, provider: self)
        }
    }

    var hooks: [any OpenFeature.Hook] = []
    var metadata: OpenFeature.ProviderMetadata = DoMetadata()

    func getBooleanEvaluation(key: String, defaultValue: Bool, context: EvaluationContext?) throws
        -> ProviderEvaluation<
            Bool
        >
    {
        if (ready) {
            return ProviderEvaluation(value: !defaultValue)
        } else {
            throw OpenFeatureError.providerNotReadyError
        }
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

    public struct DoMetadata: ProviderMetadata {
        public var name: String? = DoSomethingProvider.name
    }
}
