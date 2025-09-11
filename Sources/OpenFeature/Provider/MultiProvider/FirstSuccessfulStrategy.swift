/// FirstSuccessfulStrategy is a strategy that evaluates a feature flag across multiple providers
/// and returns the first result. Similar to `FirstMatchStrategy` but does not bubble up individual provider errors.
/// If no provider successfully responds, it will return an error.
final public class FirstSuccessfulStrategy: Strategy {
    public func evaluate<T>(
        providers: [FeatureProvider],
        key: String,
        defaultValue: T,
        evaluationContext: EvaluationContext?,
        flagEvaluation: FlagEvaluation<T>
    ) throws -> ProviderEvaluation<T> where T: AllowedFlagValueType {
        var flagNotFound = false
        for provider in providers {
            do {
                let eval = try flagEvaluation(provider)(key, defaultValue, evaluationContext)
                if eval.errorCode == nil {
                    return eval
                } else if eval.errorCode == ErrorCode.flagNotFound {
                    flagNotFound = true
                }
            } catch OpenFeatureError.flagNotFoundError {
                flagNotFound = true
            } catch {
                continue
            }
        }

        let errorCode = flagNotFound ? ErrorCode.flagNotFound : ErrorCode.general
        return ProviderEvaluation(
            value: defaultValue,
            reason: Reason.defaultReason.rawValue,
            errorCode: errorCode
        )
    }
}
