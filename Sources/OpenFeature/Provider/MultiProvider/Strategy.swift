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
    /// Aggregate status from all providers to determine the final
    /// status of the MultiProvider.
    ///
    /// The default implementation selects the best status based on
    /// the following priorities:
    /// reconciling > stale > ready > error > notReady > fatal.
    func status(providers: [FeatureProvider]) -> ProviderStatus

    func evaluate<T>(
        providers: [FeatureProvider],
        key: String,
        defaultValue: T,
        evaluationContext: EvaluationContext?,
        flagEvaluation: FlagEvaluation<T>
    ) throws -> ProviderEvaluation<T> where T: AllowedFlagValueType
}

extension Strategy {
    public func status(providers: [FeatureProvider]) -> ProviderStatus {
        func priority(of status: ProviderStatus) -> Int {
            switch status {
            case .fatal: 0
            case .notReady: 1
            case .error: 2
            case .ready: 3
            case .stale: 4
            case .reconciling: 5
            }
        }

        var bestStatus = ProviderStatus.fatal
        for provider in providers {
            let providerStatus = provider.status
            if priority(of: providerStatus) > priority(of: bestStatus) {
                bestStatus = providerStatus
            }
        }

        return bestStatus
    }
}
