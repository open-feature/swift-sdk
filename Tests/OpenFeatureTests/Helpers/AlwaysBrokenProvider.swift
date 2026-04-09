import Combine
import Foundation

@testable import OpenFeature

class AlwaysBrokenProvider: FeatureProvider {
    var metadata: ProviderMetadata = AlwaysBrokenMetadata()
    var hooks: [any Hook] = []
    var throwFatal = false
    private let statusTracker = ProviderStatusTracker()
    var status: ProviderStatus { statusTracker.status }

    func onContextSet(
        oldContext: EvaluationContext?,
        newContext: EvaluationContext
    ) -> Future<Void, Never> {
        return Future { promise in
            self.statusTracker.send(.error(nil))
            promise(.success(()))
        }
    }

    func initialize(initialContext: EvaluationContext?) -> Future<Void, Never> {
        return Future { promise in
            self.statusTracker.send(.error(nil))
            promise(.success(()))
        }
    }

    func getBooleanEvaluation(key: String, defaultValue: Bool, context: EvaluationContext?) throws
        -> OpenFeature.ProviderEvaluation<Bool>
    {
        if self.throwFatal {
            throw OpenFeatureError.providerFatalError(message: "Always broken")
        }
        throw OpenFeatureError.flagNotFoundError(key: key)
    }

    func getStringEvaluation(key: String, defaultValue: String, context: EvaluationContext?) throws
        -> OpenFeature.ProviderEvaluation<String>
    {
        if self.throwFatal {
            throw OpenFeatureError.providerFatalError(message: "Always broken")
        }
        throw OpenFeatureError.flagNotFoundError(key: key)
    }

    func getIntegerEvaluation(key: String, defaultValue: Int64, context: EvaluationContext?) throws
        -> OpenFeature.ProviderEvaluation<Int64>
    {
        if self.throwFatal {
            throw OpenFeatureError.providerFatalError(message: "Always broken")
        }
        throw OpenFeatureError.flagNotFoundError(key: key)
    }

    func getDoubleEvaluation(key: String, defaultValue: Double, context: EvaluationContext?) throws
        -> OpenFeature.ProviderEvaluation<Double>
    {
        if self.throwFatal {
            throw OpenFeatureError.providerFatalError(message: "Always broken")
        }
        throw OpenFeatureError.flagNotFoundError(key: key)
    }

    func getObjectEvaluation(key: String, defaultValue: OpenFeature.Value, context: EvaluationContext?) throws
        -> OpenFeature.ProviderEvaluation<OpenFeature.Value>
    {
        if self.throwFatal {
            throw OpenFeatureError.providerFatalError(message: "Always broken")
        }
        throw OpenFeatureError.flagNotFoundError(key: key)
    }

    func observe() -> AnyPublisher<ProviderEvent, Never> {
        statusTracker.observe()
    }
}

extension AlwaysBrokenProvider {
    struct AlwaysBrokenMetadata: ProviderMetadata {
        var name: String? = "test"
    }
}
