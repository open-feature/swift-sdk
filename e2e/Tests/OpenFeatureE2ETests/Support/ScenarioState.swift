import Foundation
import OpenFeature
import XCTest

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
            XCTFail("No scenario state: 'Given a stable provider' did not run for this scenario")
            return reset()
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
