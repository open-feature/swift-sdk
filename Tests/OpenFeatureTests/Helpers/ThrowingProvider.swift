import Combine
import Foundation

@testable import OpenFeature

class ThrowingProvider: FeatureProvider {
    var metadata: ProviderMetadata = ThrowingProviderMetadata()
    var hooks: [any Hook] = []
    private let statusTracker = ProviderStatusTracker()
    var status: ProviderStatus { statusTracker.status }

    func onContextSet(
        oldContext: EvaluationContext?,
        newContext: EvaluationContext
    ) -> Future<Void, Never> {
        return Future { promise in
            self.statusTracker.send(.error(ProviderEventDetails(errorCode: .providerFatal)))
            promise(.success(()))
        }
    }

    func initialize(initialContext: EvaluationContext?) -> Future<Void, Never> {
        return Future { promise in
            self.statusTracker.send(.error(ProviderEventDetails(errorCode: .providerFatal)))
            promise(.success(()))
        }
    }

    func getBooleanEvaluation(key: String, defaultValue: Bool, context: EvaluationContext?) throws
        -> OpenFeature.ProviderEvaluation<Bool>
    {
        throw OpenFeatureError.providerFatalError(message: "Provider is in fatal state")
    }

    func getStringEvaluation(key: String, defaultValue: String, context: EvaluationContext?) throws
        -> OpenFeature.ProviderEvaluation<String>
    {
        throw OpenFeatureError.providerFatalError(message: "Provider is in fatal state")
    }

    func getIntegerEvaluation(key: String, defaultValue: Int64, context: EvaluationContext?) throws
        -> OpenFeature.ProviderEvaluation<Int64>
    {
        throw OpenFeatureError.providerFatalError(message: "Provider is in fatal state")
    }

    func getDoubleEvaluation(key: String, defaultValue: Double, context: EvaluationContext?) throws
        -> OpenFeature.ProviderEvaluation<Double>
    {
        throw OpenFeatureError.providerFatalError(message: "Provider is in fatal state")
    }

    func getObjectEvaluation(key: String, defaultValue: OpenFeature.Value, context: EvaluationContext?) throws
        -> OpenFeature.ProviderEvaluation<OpenFeature.Value>
    {
        throw OpenFeatureError.providerFatalError(message: "Provider is in fatal state")
    }

    func observe() -> AnyPublisher<ProviderEvent, Never> {
        statusTracker.observe()
    }
}

extension ThrowingProvider {
    struct ThrowingProviderMetadata: ProviderMetadata {
        var name: String? = "test"
    }
}
