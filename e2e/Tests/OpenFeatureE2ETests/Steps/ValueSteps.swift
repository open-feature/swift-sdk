import CucumberSwift
import Foundation
import OpenFeature
import XCTest

extension Cucumber {
    @available(*, deprecated, message: "See StepRegistration.swift")
    func registerValueSteps() {
        when(EvaluationPatterns.booleanValue) { matches, _ in
            let state = ScenarioState.current
            state.flagKey = capture(matches, 1)
            state.booleanValue = OpenFeatureAPI.shared.getClient().getBooleanValue(
                key: capture(matches, 1),
                defaultValue: GherkinArguments.bool(capture(matches, 2)))
        }
        then(EvaluationPatterns.booleanValueResult) { matches, _ in
            XCTAssertEqual(
                ScenarioState.current.booleanValue, GherkinArguments.bool(capture(matches, 1)))
        }

        when(EvaluationPatterns.stringValue) { matches, _ in
            let state = ScenarioState.current
            state.flagKey = capture(matches, 1)
            state.stringValue = OpenFeatureAPI.shared.getClient().getStringValue(
                key: capture(matches, 1), defaultValue: capture(matches, 2))
        }
        then(EvaluationPatterns.stringValueResult) { matches, _ in
            XCTAssertEqual(ScenarioState.current.stringValue, capture(matches, 1))
        }

        when(EvaluationPatterns.integerValue) { matches, _ in
            let state = ScenarioState.current
            state.flagKey = capture(matches, 1)
            state.integerValue = OpenFeatureAPI.shared.getClient().getIntegerValue(
                key: capture(matches, 1),
                defaultValue: GherkinArguments.integer(capture(matches, 2)))
        }
        then(EvaluationPatterns.integerValueResult) { matches, _ in
            XCTAssertEqual(
                ScenarioState.current.integerValue, GherkinArguments.integer(capture(matches, 1)))
        }

        when(EvaluationPatterns.floatValue) { matches, _ in
            let state = ScenarioState.current
            state.flagKey = capture(matches, 1)
            state.doubleValue = OpenFeatureAPI.shared.getClient().getDoubleValue(
                key: capture(matches, 1),
                defaultValue: GherkinArguments.double(capture(matches, 2)))
        }
        then(EvaluationPatterns.floatValueResult) { matches, _ in
            XCTAssertEqual(
                ScenarioState.current.doubleValue, GherkinArguments.double(capture(matches, 1)))
        }

        when(EvaluationPatterns.objectValue) { matches, _ in
            let state = ScenarioState.current
            state.flagKey = capture(matches, 1)
            state.objectValue = OpenFeatureAPI.shared.getClient().getObjectValue(
                key: capture(matches, 1), defaultValue: .null)
        }
        then(EvaluationPatterns.objectValueResult) { matches, _ in
            GherkinArguments.assertObjectPayload(ScenarioState.current.objectValue, matches)
        }
    }
}
