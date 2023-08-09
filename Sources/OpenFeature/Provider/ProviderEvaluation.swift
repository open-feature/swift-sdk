import Foundation

public struct ProviderEvaluation<T> {
    public var value: T
    public var variant: String?
    public var reason: String?
    public var errorCode: ErrorCode?
    public var errorMessage: String?

    public init(
        value: T,
        variant: String? = nil,
        reason: String? = nil,
        errorCode: ErrorCode? = nil,
        errorMessage: String? = nil
    ) {
        self.value = value
        self.variant = variant
        self.reason = reason
        self.errorCode = errorCode
        self.errorMessage = errorMessage
    }
}
