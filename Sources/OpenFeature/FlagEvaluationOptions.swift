import Foundation
import Logging

/// FlagEvaluationOptions is a struct that enables passing in custom hooks and hints to the flag evaluation process.
public struct FlagEvaluationOptions {
    public let hooks: [any Hook]
    public let hookHints: [String: Any]
    public let logger: Logger?

    public init(
        hooks: [any Hook] = [],
        hookHints: [String: Any] = [:],
        logger: Logger? = nil
    ) {
        self.hooks = hooks
        self.hookHints = hookHints
        self.logger = logger
    }
}
