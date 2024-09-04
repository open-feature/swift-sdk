import Foundation

/// The interface implemented by upstream flag providers to resolve flags for their service.
public protocol FeatureProvider: EventPublisher {
    var hooks: [any Hook] { get }
    var metadata: ProviderMetadata { get }

    /// Called by OpenFeatureAPI whenever the new Provider is registered
    /// This must throw in case of error, using OpenFeature errors whenever possible
    /// It is expected that the implementer is slow (e.g. network), hence the async nature of the protocol
    func initialize(initialContext: EvaluationContext?) async throws

    /// Called by OpenFeatureAPI whenever a new EvaluationContext is set by the application
    /// This must throw in case of error, using OpenFeature errors whenever possible
    /// It is expected that the implementer is slow (e.g. network), hence the async nature of the protocol
    func onContextSet(oldContext: EvaluationContext?, newContext: EvaluationContext) async throws

    func getBooleanEvaluation(key: String, defaultValue: Bool, context: EvaluationContext?) throws
        -> ProviderEvaluation<
            Bool
        >
    func getStringEvaluation(key: String, defaultValue: String, context: EvaluationContext?) throws
        -> ProviderEvaluation<
            String
        >
    func getIntegerEvaluation(key: String, defaultValue: Int64, context: EvaluationContext?) throws
        -> ProviderEvaluation<
            Int64
        >
    func getDoubleEvaluation(key: String, defaultValue: Double, context: EvaluationContext?) throws
        -> ProviderEvaluation<
            Double
        >
    func getObjectEvaluation(key: String, defaultValue: Value, context: EvaluationContext?) throws
        -> ProviderEvaluation<
            Value
        >
}
