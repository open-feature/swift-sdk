import Foundation

public struct ComparisonStrategyResolutionResult {
    public let provider: FeatureProvider
    public let providerName: String
    public let details: Any?
    public let error: Error?
    public let errorCode: ErrorCode?
    public let errorMessage: String?

    public init(
        provider: FeatureProvider,
        providerName: String,
        details: Any? = nil,
        error: Error? = nil,
        errorCode: ErrorCode? = nil,
        errorMessage: String? = nil
    ) {
        self.provider = provider
        self.providerName = providerName
        self.details = details
        self.error = error
        self.errorCode = errorCode
        self.errorMessage = errorMessage
    }
}

public enum ComparisonStrategyError: Error, LocalizedError {
    case providerErrors([ComparisonStrategyResolutionResult])
    case fallbackProviderNotFound

    public var errorDescription: String? {
        switch self {
        case .providerErrors(let results):
            let messages = results.compactMap { result -> String? in
                if let error = result.error {
                    return "\(result.providerName): \(error)"
                }
                if let errorMessage = result.errorMessage {
                    return "\(result.providerName): \(errorMessage)"
                }
                if let errorCode = result.errorCode {
                    return "\(result.providerName): \(errorCode)"
                }
                return nil
            }
            return messages.isEmpty ? "Comparison strategy encountered provider errors." : messages.joined(separator: ", ")
        case .fallbackProviderNotFound:
            return "Fallback provider not found in comparison strategy providers."
        }
    }
}

/// ComparisonStrategy evaluates all providers and compares their results.
/// If results disagree, the fallback provider's result is returned and the `onMismatch` callback is invoked.
///
/// - Note: The JS SDK evaluates providers in parallel (`runMode = 'parallel'`). This Swift implementation
///   evaluates providers sequentially because the `Strategy` protocol's synchronous `evaluate` method
///   does not support async execution. Parallel evaluation would require changing the protocol to be async.
final public class ComparisonStrategy: Strategy {
    private let fallbackProvider: FeatureProvider
    private let onMismatch: (([ComparisonStrategyResolutionResult]) -> Void)?

    public init(
        fallbackProvider: FeatureProvider,
        onMismatch: (([ComparisonStrategyResolutionResult]) -> Void)? = nil
    ) {
        self.fallbackProvider = fallbackProvider
        self.onMismatch = onMismatch
    }

    public func evaluate<T>(
        providers: [FeatureProvider],
        key: String,
        defaultValue: T,
        evaluationContext: EvaluationContext?,
        flagEvaluation: FlagEvaluation<T>
    ) throws -> ProviderEvaluation<T> where T: AllowedFlagValueType {
        guard !providers.isEmpty else {
            return ProviderEvaluation(
                value: defaultValue,
                reason: Reason.defaultReason.rawValue,
                errorCode: .flagNotFound
            )
        }

        let providerNames = makeUniqueProviderNames(providers)
        var resolutions: [ComparisonStrategyResolutionResult] = []
        var fallbackResolution: ProviderEvaluation<T>?
        var firstResolution: ProviderEvaluation<T>?
        var expectedValue: T?
        var mismatchDetected = false
        var encounteredError = false

        for (index, provider) in providers.enumerated() {
            do {
                let evaluation = try flagEvaluation(provider)(key, defaultValue, evaluationContext)
                resolutions.append(
                    ComparisonStrategyResolutionResult(
                        provider: provider,
                        providerName: providerNames[index],
                        details: evaluation,
                        errorCode: evaluation.errorCode,
                        errorMessage: evaluation.errorMessage
                    )
                )

                if providersMatch(provider, fallbackProvider) {
                    fallbackResolution = evaluation
                }
                if firstResolution == nil {
                    firstResolution = evaluation
                }

                if evaluation.errorCode != nil {
                    encounteredError = true
                    continue
                }

                if let expectedValue, expectedValue != evaluation.value {
                    mismatchDetected = true
                } else {
                    expectedValue = evaluation.value
                }
            } catch {
                encounteredError = true
                resolutions.append(
                    ComparisonStrategyResolutionResult(
                        provider: provider,
                        providerName: providerNames[index],
                        error: error,
                        errorMessage: "\(error)"
                    )
                )
            }
        }

        if encounteredError {
            throw ComparisonStrategyError.providerErrors(resolutions)
        }

        guard let fallbackResolution else {
            throw ComparisonStrategyError.fallbackProviderNotFound
        }

        if mismatchDetected {
            onMismatch?(resolutions)
            return fallbackResolution
        }

        return firstResolution ?? fallbackResolution
    }

    private func providersMatch(_ lhs: FeatureProvider, _ rhs: FeatureProvider) -> Bool {
        let lhsObject = lhs as AnyObject
        let rhsObject = rhs as AnyObject
        return lhsObject === rhsObject
    }
}
