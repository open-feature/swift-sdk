/// FirstMatchStrategy is a strategy that evaluates a feature flag across multiple providers
/// and returns the first result. Similar to `FirstFoundStrategy` but does not bubble up individual provider errors.
/// If no provider successfully responds, it will return an error.
final public class FirstMatchStrategy: Strategy {
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

        return ProviderEvaluation(
            value: defaultValue,
            reason: Reason.defaultReason.rawValue,
            errorCode: ErrorCode.flagNotFound
        )
    }
}
