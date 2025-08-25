/// FlagEvaluation is a function that evaluates a feature flag and returns a ProviderEvaluation.
/// It is used to evaluate a feature flag across multiple providers using the strategy's logic.
public typealias FlagEvaluation<T> = (FeatureProvider) -> (
    _ key: String, _ defaultValue: T, _ evaluationContext: EvaluationContext?
) throws -> ProviderEvaluation<T> where T: AllowedFlagValueType

/// Strategy interface defines how multiple feature providers should be evaluated
/// to determine the final result for a feature flag evaluation.
/// Different strategies can implement different logic for combining or selecting
/// results from multiple providers.
public protocol Strategy {
    func evaluate<T>(
        providers: [FeatureProvider],
        key: String,
        defaultValue: T,
        evaluationContext: EvaluationContext?,
        flagEvaluation: FlagEvaluation<T>
    ) throws -> ProviderEvaluation<T> where T: AllowedFlagValueType
}
