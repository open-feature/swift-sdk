import Foundation

/// A single flag definition used by ``InMemoryProvider``.
public struct InMemoryFlag {
    /// Returns the key of the variant to resolve, or `nil` to fall back to ``defaultVariant``.
    public typealias ContextEvaluator = (InMemoryFlag, EvaluationContext?) -> String?

    public let variants: [String: Value]
    public let defaultVariant: String
    public let contextEvaluator: ContextEvaluator?
    public let flagMetadata: FlagMetadata

    /// When `true`, evaluations return the caller's default value with reason `DISABLED`.
    public let disabled: Bool

    public init(
        variants: [String: Value],
        defaultVariant: String,
        contextEvaluator: ContextEvaluator? = nil,
        flagMetadata: FlagMetadata = [:],
        disabled: Bool = false
    ) {
        self.variants = variants
        self.defaultVariant = defaultVariant
        self.contextEvaluator = contextEvaluator
        self.flagMetadata = flagMetadata
        self.disabled = disabled
    }
}
