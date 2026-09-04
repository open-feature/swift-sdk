import Foundation
import OpenFeature

/// Per-scenario state, installed by the `Given a stable provider` background step.
///
/// Step closures are registered once on the `Cucumber.shared` singleton and reused by every
/// scenario, so state captured in `setupSteps()` would leak between scenarios.
final class ScenarioState {
    private static let lock = NSLock()
    private static var storage: ScenarioState?

    @discardableResult
    static func reset() -> ScenarioState {
        let state = ScenarioState()
        lock.withLock { storage = state }
        return state
    }

    static func clear() {
        lock.withLock { storage = nil }
    }

    static var current: ScenarioState {
        guard let state = lock.withLock({ storage }) else {
            preconditionFailure(
                "No scenario state: 'Given a stable provider' did not run for this scenario")
        }
        return state
    }

    var flagKey: String?

    var booleanValue: Bool?
    var stringValue: String?
    var integerValue: Int64?
    var doubleValue: Double?
    var objectValue: Value?

    var booleanDetails: FlagEvaluationDetails<Bool>?
    var stringDetails: FlagEvaluationDetails<String>?
    var integerDetails: FlagEvaluationDetails<Int64>?
    var doubleDetails: FlagEvaluationDetails<Double>?
    var objectDetails: FlagEvaluationDetails<Value>?

    var stringFallback: String?
    var integerFallback: Int64?
}
