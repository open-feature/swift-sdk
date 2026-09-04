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
            XCTAssertEqual(state.stringDetails?.value, state.stringFallback)
        }
        then(EvaluationPatterns.flagNotFoundReason) { matches, _ in
            let details = ScenarioState.current.stringDetails
            XCTAssertEqual(details?.reason, Reason.error.rawValue)
            XCTAssertEqual(details?.errorCode, GherkinArguments.errorCode(capture(matches, 1)))
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
            XCTAssertEqual(state.integerDetails?.value, state.integerFallback)
        }
        then(EvaluationPatterns.typeMismatchReason) { matches, _ in
            let details = ScenarioState.current.integerDetails
            XCTAssertEqual(details?.reason, Reason.error.rawValue)
            XCTAssertEqual(details?.errorCode, GherkinArguments.errorCode(capture(matches, 1)))
        }
    }
}
