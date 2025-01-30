import Foundation
import os

class HookSupport {
    var logger = Logger()

    func beforeHooks<T>(flagValueType: FlagValueType, hookCtx: HookContext<T>, hooks: [any Hook], hints: [String: Any])
    {
        hooks
            .reversed()
            .filter { $0.supportsFlagValueType(flagValueType: flagValueType) }
            .forEach { $0.before(ctx: hookCtx, hints: hints) }
    }

    func afterHooks<T>(
        flagValueType: FlagValueType,
        hookCtx: HookContext<T>,
        details: FlagEvaluationDetails<T>,
        hooks: [any Hook],
        hints: [String: Any]
    ) throws {
        hooks
            .filter { $0.supportsFlagValueType(flagValueType: flagValueType) }
            .forEach { $0.after(ctx: hookCtx, details: details, hints: hints) }
    }

    func errorHooks<T>(
        flagValueType: FlagValueType, hookCtx: HookContext<T>, error: Error, hooks: [any Hook], hints: [String: Any]
    ) {
        hooks
            .filter { $0.supportsFlagValueType(flagValueType: flagValueType) }
            .forEach { $0.error(ctx: hookCtx, error: error, hints: hints) }
    }

    func finallyHooks<T>(
        flagValueType: FlagValueType,
        hookCtx: HookContext<T>,
        details: FlagEvaluationDetails<T>,
        hooks: [any Hook],
        hints: [String: Any]
    ) {
        hooks
            .filter { $0.supportsFlagValueType(flagValueType: flagValueType) }
            .forEach { $0.finally(ctx: hookCtx, details: details, hints: hints) }
    }
}
