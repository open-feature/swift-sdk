import Combine
import Foundation

@testable import OpenFeature

class ThrowingProvider: FeatureProvider {
    var metadata: ProviderMetadata = ThrowingProviderMetadata()
    var hooks: [any Hook] = []
    private let eventHandler = EventHandler()

    func onContextSet(oldContext: OpenFeature.EvaluationContext?, newContext: OpenFeature.EvaluationContext) throws {
        throw OpenFeatureError.providerFatalError(message: "Wrong credentials")
    }

    func initialize(initialContext: OpenFeature.EvaluationContext?) throws {
        throw OpenFeatureError.providerFatalError(message: "Wrong credentials")
    }

    func getBooleanEvaluation(key: String, defaultValue: Bool, context: EvaluationContext?) throws
        -> OpenFeature.ProviderEvaluation<Bool>
    {
        throw OpenFeatureError.flagNotFoundError(key: key)
    }

    func getStringEvaluation(key: String, defaultValue: String, context: EvaluationContext?) throws
        -> OpenFeature.ProviderEvaluation<String>
    {
        throw OpenFeatureError.flagNotFoundError(key: key)
    }

    func getIntegerEvaluation(key: String, defaultValue: Int64, context: EvaluationContext?) throws
        -> OpenFeature.ProviderEvaluation<Int64>
    {
        throw OpenFeatureError.flagNotFoundError(key: key)
    }

    func getDoubleEvaluation(key: String, defaultValue: Double, context: EvaluationContext?) throws
        -> OpenFeature.ProviderEvaluation<Double>
    {
        throw OpenFeatureError.flagNotFoundError(key: key)
    }

    func getObjectEvaluation(key: String, defaultValue: OpenFeature.Value, context: EvaluationContext?) throws
        -> OpenFeature.ProviderEvaluation<OpenFeature.Value>
    {
        throw OpenFeatureError.flagNotFoundError(key: key)
    }

    func observe() -> AnyPublisher<ProviderEvent?, Never> {
        eventHandler.observe()
    }
}

extension ThrowingProvider {
    struct ThrowingProviderMetadata: ProviderMetadata {
        var name: String? = "test"
    }
}
