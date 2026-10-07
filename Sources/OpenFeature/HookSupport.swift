import Foundation

/// Dispatches the stages of a flag evaluation to hooks, each paired with its own ``HookContext``.
///
/// ``OpenFeatureClient`` builds the pairs once per evaluation from the hooks that support the flag's value type, so
/// every hook sees the same ``HookData`` at every stage. Nothing is filtered here, which keeps hooks and contexts
/// from ever going out of step.
class HookSupport {
    typealias HookWithContext<T> = (hook: any Hook, ctx: HookContext<T>)

    func beforeHooks<T>(hooksWithContext: [HookWithContext<T>], hints: [String: Any]) {
        hooksWithContext
            .reversed()
            .forEach { $0.hook.before(ctx: $0.ctx, hints: hints) }
    }

    func afterHooks<T>(
        hooksWithContext: [HookWithContext<T>],
        details: FlagEvaluationDetails<T>,
        hints: [String: Any]
    ) {
        hooksWithContext.forEach { $0.hook.after(ctx: $0.ctx, details: details, hints: hints) }
    }

    func errorHooks<T>(hooksWithContext: [HookWithContext<T>], error: Error, hints: [String: Any]) {
        hooksWithContext.forEach { $0.hook.error(ctx: $0.ctx, error: error, hints: hints) }
    }

    func finallyHooks<T>(
        hooksWithContext: [HookWithContext<T>],
        details: FlagEvaluationDetails<T>,
        hints: [String: Any]
    ) {
        hooksWithContext.forEach { $0.hook.finally(ctx: $0.ctx, details: details, hints: hints) }
    }
}
