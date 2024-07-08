import Foundation

/// Contains information about how the evaluation happened, including any resolved values.
public struct FlagEvaluationDetails<T: Equatable>: BaseEvaluation, Equatable {
    public var flagKey: String
    public var value: T
    public var variant: String?
    public var reason: String?
    public var flagMetadata: [String: FlagMetadataValue]
    public var errorCode: ErrorCode?
    public var errorMessage: String?

    public init(
        flagKey: String,
        value: T,
        flagMetadata: [String: FlagMetadataValue] = [:],
        variant: String? = nil,
        reason: String? = nil,
        errorCode: ErrorCode? = nil,
        errorMessage: String? = nil
    ) {
        self.flagKey = flagKey
        self.value = value
        self.variant = variant
        self.reason = reason
        self.flagMetadata = flagMetadata
        self.errorCode = errorCode
        self.errorMessage = errorMessage
    }

    public static func from(providerEval: ProviderEvaluation<T>, flagKey: String) -> FlagEvaluationDetails<T> {
        return FlagEvaluationDetails(
            flagKey: flagKey,
            value: providerEval.value,
            flagMetadata: providerEval.flagMetadata,
            variant: providerEval.variant,
            reason: providerEval.reason,
            errorCode: providerEval.errorCode,
            errorMessage: providerEval.errorMessage)
    }
}
