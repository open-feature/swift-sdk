import Foundation

/// A ``FeatureProvider`` that simply returns the default values passed to it.
class NoOpProvider: FeatureProvider {
    public static let passedInDefault = "Passed in default"

    public enum Mode {
        case normal
        case error(message: String)
    }

    var metadata: ProviderMetadata = NoOpMetadata(name: "No-op provider")
    var hooks: [any Hook] = []

    func onContextSet(oldContext: EvaluationContext?, newContext: EvaluationContext) {
        OpenFeatureAPI.shared.emitEvent(.configurationChanged, provider: self)
    }

    func initialize(initialContext: EvaluationContext?) {
        OpenFeatureAPI.shared.emitEvent(.ready, provider: self)
    }

    func getBooleanEvaluation(key: String, defaultValue: Bool, context: EvaluationContext?) throws
        -> ProviderEvaluation<
            Bool
        >
    {
        return ProviderEvaluation(
            value: defaultValue, variant: NoOpProvider.passedInDefault, reason: Reason.defaultReason.rawValue)
    }

    func getStringEvaluation(key: String, defaultValue: String, context: EvaluationContext?) throws
        -> ProviderEvaluation<
            String
        >
    {
        return ProviderEvaluation(
            value: defaultValue, variant: NoOpProvider.passedInDefault, reason: Reason.defaultReason.rawValue)
    }

    func getIntegerEvaluation(key: String, defaultValue: Int64, context: EvaluationContext?) throws
        -> ProviderEvaluation<
            Int64
        >
    {
        return ProviderEvaluation(
            value: defaultValue, variant: NoOpProvider.passedInDefault, reason: Reason.defaultReason.rawValue)
    }

    func getDoubleEvaluation(key: String, defaultValue: Double, context: EvaluationContext?) throws
        -> ProviderEvaluation<
            Double
        >
    {
        return ProviderEvaluation(
            value: defaultValue, variant: NoOpProvider.passedInDefault, reason: Reason.defaultReason.rawValue)
    }

    func getObjectEvaluation(key: String, defaultValue: Value, context: EvaluationContext?) throws
        -> ProviderEvaluation<
            Value
        >
    {
        return ProviderEvaluation(
            value: defaultValue, variant: NoOpProvider.passedInDefault, reason: Reason.defaultReason.rawValue)
    }
}

extension NoOpProvider {
    struct NoOpMetadata: ProviderMetadata {
        var name: String?
    }
}
