/// FirstSuccessfulStrategy is a strategy that evaluates a feature flag across multiple providers
/// and returns the first result. Similar to `FirstMatchStrategy` but does not bubble up individual provider errors.
/// If no provider successfully responds, it will throw an error.
final public class FirstSuccessfulStrategy: Strategy {
    public func evaluate<T>(
        providers: [FeatureProvider],
        key: String,
        defaultValue: T,
        evaluationContext: EvaluationContext?,
        flagEvaluation: FlagEvaluation<T>
    ) throws -> ProviderEvaluation<T> where T: AllowedFlagValueType {
        for provider in providers {
            do {
                let eval = try flagEvaluation(provider)(key, defaultValue, evaluationContext)
                if eval.errorCode == nil {
                    return eval
                }
            } catch {
                continue
            }
        }

        throw OpenFeatureError.flagNotFoundError(key: key)
    }
}
