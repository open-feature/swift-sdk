import Foundation

/// FlagEvaluationOptions is a struct that enables passing in custom hooks and hints to the flag evaluation process.
public struct FlagEvaluationOptions {
    /// Hooks run for this evaluation only, in addition to API, client and provider hooks.
    public let hooks: [any Hook]
    /// Arbitrary hints passed to every hook run during this evaluation.
    public let hookHints: [String: Any]
    /// Logger for this evaluation only. Takes precedence over the client and API-level loggers.
    public let logger: (any OpenFeatureLogger)?

    /// Creates evaluation options.
    /// - Parameters:
    ///   - hooks: Hooks to run for this evaluation only.
    ///   - hookHints: Hints passed to every hook run during this evaluation.
    ///   - logger: Logger to hand to the provider for this evaluation, overriding the client and API-level
    ///     loggers. When `nil`, the client logger (or else the API logger) is used.
    public init(
        hooks: [any Hook] = [],
        hookHints: [String: Any] = [:],
        logger: (any OpenFeatureLogger)? = nil
    ) {
        self.hooks = hooks
        self.hookHints = hookHints
        self.logger = logger
    }
}
