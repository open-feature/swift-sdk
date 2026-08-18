import Foundation

/// A single flag definition used by ``InMemoryProvider``.
public struct InMemoryFlag {
    /// Resolves a flag against the evaluation context, for targeting.
    ///
    /// Returns the key of the variant to resolve, or `nil` to fall back to ``defaultVariant``.
    /// A key that is not present in ``variants`` fails evaluation with
    /// ``OpenFeatureError/generalError(message:)``.
    ///
    /// The context is optional because no evaluation context exists until the application sets
    /// one.
    public typealias ContextEvaluator = (InMemoryFlag, EvaluationContext?) -> String?

    public let variants: [String: Value]

    /// Resolved when there is no ``contextEvaluator``, or when it returns `nil`.
    public let defaultVariant: String

    public let contextEvaluator: ContextEvaluator?

    /// Attached to every evaluation of this flag, including disabled ones.
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
