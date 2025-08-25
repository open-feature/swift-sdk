/// FirstMatchStrategy is a strategy that evaluates a feature flag across multiple providers
/// and returns the first result. Skips providers that indicate they had no value due to flag not found.
/// If any provider returns an error result other than flag not found, the error is returned.
final public class FirstMatchStrategy: Strategy {

    public init() {}

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
                if eval.errorCode != ErrorCode.flagNotFound {
                    return eval
                }
            } catch OpenFeatureError.flagNotFoundError {
                continue
            } catch {
                throw error
            }
        }

        return ProviderEvaluation(
            value: defaultValue,
            reason: Reason.defaultReason.rawValue,
            errorCode: ErrorCode.flagNotFound
        )
    }
}
