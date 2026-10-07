import Foundation
import OpenFeature

/// A hook that hands its `HookData` to a closure at every stage, so tests can observe what each stage sees.
///
/// Generic over the flag value type so a test can mix hooks for different types in one evaluation. Every
/// `HookData` instance the hook is handed is also recorded, in call order, so tests can check identity across
/// stages, hooks and evaluations.
class HookDataSpyHook<V: AllowedFlagValueType>: Hook {
    typealias HookValue = V

    var onBefore: ((HookData) -> Void)?
    var onAfter: ((HookData) -> Void)?
    var onError: ((HookData) -> Void)?
    var onFinally: ((HookData) -> Void)?

    private let lock = NSLock()
    private var recorded: [HookData] = []

    /// Every `HookData` instance this hook has been handed, across all stages and evaluations, in call order.
    var seenHookData: [HookData] {
        lock.withLock { recorded }
    }

    init(
        onBefore: ((HookData) -> Void)? = nil,
        onAfter: ((HookData) -> Void)? = nil,
        onError: ((HookData) -> Void)? = nil,
        onFinally: ((HookData) -> Void)? = nil
    ) {
        self.onBefore = onBefore
        self.onAfter = onAfter
        self.onError = onError
        self.onFinally = onFinally
    }

    func before<HookValue>(ctx: HookContext<HookValue>, hints: [String: Any]) {
        record(ctx.hookData)
        onBefore?(ctx.hookData)
    }

    func after<HookValue>(ctx: HookContext<HookValue>, details: FlagEvaluationDetails<HookValue>, hints: [String: Any])
    {
        record(ctx.hookData)
        onAfter?(ctx.hookData)
    }

    func error<HookValue>(ctx: HookContext<HookValue>, error: Error, hints: [String: Any]) {
        record(ctx.hookData)
        onError?(ctx.hookData)
    }

    func finally<HookValue>(
        ctx: HookContext<HookValue>, details: FlagEvaluationDetails<HookValue>, hints: [String: Any]
    ) {
        record(ctx.hookData)
        onFinally?(ctx.hookData)
    }

    private func record(_ hookData: HookData) {
        lock.withLock { recorded.append(hookData) }
    }
}
