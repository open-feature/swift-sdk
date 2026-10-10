import Foundation
import OpenFeature

/// A hook that builds the telemetry event of every evaluation in its `finally` stage and keeps it for inspection.
///
/// It runs for every flag value type, the way a real telemetry hook would, which also proves that
/// `Telemetry.createEvaluationEvent` can be called from a hook's generic stage methods.
final class TelemetryCapturingHook: Hook {
    typealias HookValue = Bool

    private let lock = NSLock()
    private var recorded: [EvaluationEvent] = []

    /// Every event created so far, in evaluation order.
    var events: [EvaluationEvent] {
        lock.withLock { recorded }
    }

    func supportsFlagValueType(flagValueType: FlagValueType) -> Bool {
        true
    }

    func finally<HookValue>(
        ctx: HookContext<HookValue>, details: FlagEvaluationDetails<HookValue>, hints: [String: Any]
    ) {
        let event = Telemetry.createEvaluationEvent(hookContext: ctx, evaluationDetails: details)
        lock.withLock { recorded.append(event) }
    }
}
