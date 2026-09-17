import CucumberSwift
import Foundation
import OpenFeature
import XCTest

extension Cucumber {
    @available(*, deprecated, message: "See StepRegistration.swift")
    func registerDetailsSteps() {
        registerBooleanAndStringDetailsSteps()
        registerNumericDetailsSteps()
        registerObjectDetailsSteps()
    }

    @available(*, deprecated, message: "See StepRegistration.swift")
    private func registerBooleanAndStringDetailsSteps() {
        when(EvaluationPatterns.booleanDetails) { matches, _ in
            let state = ScenarioState.current
            state.flagKey = capture(matches, 1)
            state.booleanDetails = OpenFeatureAPI.shared.getClient().getBooleanDetails(
                key: capture(matches, 1),
                defaultValue: GherkinArguments.bool(capture(matches, 2)))
        }
        then(EvaluationPatterns.booleanDetailsResult) { matches, _ in
            guard let details = ScenarioState.current.booleanDetails else {
                XCTFail("no boolean details captured in this scenario")
                return
            }
            XCTAssertEqual(details.value, GherkinArguments.bool(capture(matches, 1)))
            XCTAssertEqual(details.variant, capture(matches, 2))
            XCTAssertEqual(details.reason, capture(matches, 3))
        }

        when(EvaluationPatterns.stringDetails) { matches, _ in
            let state = ScenarioState.current
            state.flagKey = capture(matches, 1)
            state.stringDetails = OpenFeatureAPI.shared.getClient().getStringDetails(
                key: capture(matches, 1), defaultValue: capture(matches, 2))
        }
        then(EvaluationPatterns.stringDetailsResult) { matches, _ in
            guard let details = ScenarioState.current.stringDetails else {
                XCTFail("no string details captured in this scenario")
                return
            }
            XCTAssertEqual(details.value, capture(matches, 1))
            XCTAssertEqual(details.variant, capture(matches, 2))
            XCTAssertEqual(details.reason, capture(matches, 3))
        }
    }

    @available(*, deprecated, message: "See StepRegistration.swift")
    private func registerNumericDetailsSteps() {
        when(EvaluationPatterns.integerDetails) { matches, _ in
            let state = ScenarioState.current
            state.flagKey = capture(matches, 1)
            state.integerDetails = OpenFeatureAPI.shared.getClient().getIntegerDetails(
                key: capture(matches, 1),
                defaultValue: GherkinArguments.integer(capture(matches, 2)))
        }
        then(EvaluationPatterns.integerDetailsResult) { matches, _ in
            guard let details = ScenarioState.current.integerDetails else {
                XCTFail("no integer details captured in this scenario")
                return
            }
            XCTAssertEqual(details.value, GherkinArguments.integer(capture(matches, 1)))
            XCTAssertEqual(details.variant, capture(matches, 2))
            XCTAssertEqual(details.reason, capture(matches, 3))
        }

        when(EvaluationPatterns.floatDetails) { matches, _ in
            let state = ScenarioState.current
            state.flagKey = capture(matches, 1)
            state.doubleDetails = OpenFeatureAPI.shared.getClient().getDoubleDetails(
                key: capture(matches, 1),
                defaultValue: GherkinArguments.double(capture(matches, 2)))
        }
        then(EvaluationPatterns.floatDetailsResult) { matches, _ in
            guard let details = ScenarioState.current.doubleDetails else {
                XCTFail("no float details captured in this scenario")
                return
            }
            XCTAssertEqual(details.value, GherkinArguments.double(capture(matches, 1)))
            XCTAssertEqual(details.variant, capture(matches, 2))
            XCTAssertEqual(details.reason, capture(matches, 3))
        }
    }

    @available(*, deprecated, message: "See StepRegistration.swift")
    private func registerObjectDetailsSteps() {
        when(EvaluationPatterns.objectDetails) { matches, _ in
            let state = ScenarioState.current
            state.flagKey = capture(matches, 1)
            state.objectDetails = OpenFeatureAPI.shared.getClient().getObjectDetails(
                key: capture(matches, 1), defaultValue: .null)
        }
        then(EvaluationPatterns.objectDetailsResult) { matches, _ in
            GherkinArguments.assertObjectPayload(ScenarioState.current.objectDetails?.value, matches)
        }
        // An `And` step whose primary keyword is Then, so `then` matches it.
        then(EvaluationPatterns.variantAndReason) { matches, _ in
            guard let details = ScenarioState.current.objectDetails else {
                XCTFail("no object details captured in this scenario")
                return
            }
            XCTAssertEqual(details.variant, capture(matches, 1))
            XCTAssertEqual(details.reason, capture(matches, 2))
        }
    }
}
