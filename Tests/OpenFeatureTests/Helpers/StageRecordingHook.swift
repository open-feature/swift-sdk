import Foundation
import OpenFeature

/// Records everything each stage receives, so tests can assert on the payloads rather than on call counts.
///
/// `HookValue` is `Bool`, so by default the hook only runs for boolean evaluations. Set `supportsAllTypes` to make
/// it run for every flag value type, the way the README's `CorrelationIDHook` does. The generic parts of the
/// context and the details are stored as `Any` and cast back by the test.
final class StageRecordingHook: Hook {
    typealias HookValue = Bool

    enum Stage: String {
        case before
        case after
        case error
        case finally
    }

    struct Invocation {
        let stage: Stage
        let flagKey: String
        let type: FlagValueType
        let defaultValue: Any
        let evaluationContext: EvaluationContext?
        let clientMetadata: ClientMetadata?
        let providerMetadata: ProviderMetadata?
        let hookData: HookData
        let details: Any?
        let error: Error?
        let hints: [String: Any]
    }

    var supportsAllTypes = false

    private let lock = NSLock()
    private var recorded: [Invocation] = []

    /// Every stage invocation, in call order, across all evaluations.
    var invocations: [Invocation] {
        lock.withLock { recorded }
    }

    /// The first invocation of `stage`, if it ran.
    func invocation(_ stage: Stage) -> Invocation? {
        invocations.first { $0.stage == stage }
    }

    /// Every invocation of `stage`, in call order.
    func invocations(_ stage: Stage) -> [Invocation] {
        invocations.filter { $0.stage == stage }
    }

    func supportsFlagValueType(flagValueType: FlagValueType) -> Bool {
        supportsAllTypes || flagValueType == .boolean
    }

    func before<HookValue>(ctx: HookContext<HookValue>, hints: [String: Any]) {
        record(.before, ctx, details: nil, error: nil, hints: hints)
    }

    func after<HookValue>(ctx: HookContext<HookValue>, details: FlagEvaluationDetails<HookValue>, hints: [String: Any])
    {
        record(.after, ctx, details: details, error: nil, hints: hints)
    }

    func error<HookValue>(ctx: HookContext<HookValue>, error: Error, hints: [String: Any]) {
        record(.error, ctx, details: nil, error: error, hints: hints)
    }

    func finally<HookValue>(
        ctx: HookContext<HookValue>, details: FlagEvaluationDetails<HookValue>, hints: [String: Any]
    ) {
        record(.finally, ctx, details: details, error: nil, hints: hints)
    }

    private func record<HookValue>(
        _ stage: Stage,
        _ ctx: HookContext<HookValue>,
        details: Any?,
        error: Error?,
        hints: [String: Any]
    ) {
        let invocation = Invocation(
            stage: stage,
            flagKey: ctx.flagKey,
            type: ctx.type,
            defaultValue: ctx.defaultValue,
            evaluationContext: ctx.ctx,
            clientMetadata: ctx.clientMetadata,
            providerMetadata: ctx.providerMetadata,
            hookData: ctx.hookData,
            details: details,
            error: error,
            hints: hints)
        lock.withLock { recorded.append(invocation) }
    }
}
