import CucumberSwift
import Foundation
import OpenFeature
import XCTest

extension Cucumber {
    @available(*, deprecated, message: "See StepRegistration.swift")
    func registerErrorSteps() {
        when(EvaluationPatterns.missingFlagDetails) { matches, _ in
            let state = ScenarioState.current
            state.flagKey = capture(matches, 1)
            state.stringFallback = capture(matches, 2)
            state.stringDetails = OpenFeatureAPI.shared.getClient().getStringDetails(
                key: capture(matches, 1), defaultValue: capture(matches, 2))
        }
        then(EvaluationPatterns.defaultStringResult) { _, _ in
            let state = ScenarioState.current
            guard let details = state.stringDetails, let fallback = state.stringFallback else {
                XCTFail("no string details captured in this scenario")
                return
            }
            XCTAssertEqual(details.value, fallback)
        }
        then(EvaluationPatterns.flagNotFoundReason) { matches, _ in
            guard let details = ScenarioState.current.stringDetails else {
                XCTFail("no string details captured in this scenario")
                return
            }
            XCTAssertEqual(details.reason, Reason.error.rawValue)
            XCTAssertEqual(details.errorCode, GherkinArguments.errorCode(capture(matches, 1)))
        }

        when(EvaluationPatterns.wrongTypeDetails) { matches, _ in
            let state = ScenarioState.current
            let fallback = GherkinArguments.integer(capture(matches, 2))
            state.flagKey = capture(matches, 1)
            state.integerFallback = fallback
            state.integerDetails = OpenFeatureAPI.shared.getClient().getIntegerDetails(
                key: capture(matches, 1), defaultValue: fallback)
        }
        then(EvaluationPatterns.defaultIntegerResult) { _, _ in
            let state = ScenarioState.current
            guard let details = state.integerDetails, let fallback = state.integerFallback else {
                XCTFail("no integer details captured in this scenario")
                return
            }
            XCTAssertEqual(details.value, fallback)
        }
        then(EvaluationPatterns.typeMismatchReason) { matches, _ in
            guard let details = ScenarioState.current.integerDetails else {
                XCTFail("no integer details captured in this scenario")
                return
            }
            XCTAssertEqual(details.reason, Reason.error.rawValue)
            XCTAssertEqual(details.errorCode, GherkinArguments.errorCode(capture(matches, 1)))
        }
    }
}
