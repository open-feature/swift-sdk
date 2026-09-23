import CucumberSwift
import Foundation
import OpenFeature
import XCTest

extension Cucumber {
    @available(*, deprecated, message: "See StepRegistration.swift")
    func registerContextSteps() {
        when(EvaluationPatterns.contextContainsKeys) { matches, _ in
            // `Client` takes no per-evaluation context, so the context is installed globally.
            let attributes: [String: Value] = [
                capture(matches, 1): GherkinArguments.boolOrString(capture(matches, 5)),
                capture(matches, 2): GherkinArguments.boolOrString(capture(matches, 6)),
                capture(matches, 3): .integer(GherkinArguments.integer(capture(matches, 7))),
                capture(matches, 4): GherkinArguments.boolOrString(capture(matches, 8)),
            ]
            AsyncBridge.run {
                await OpenFeatureAPI.shared.setEvaluationContextAndWait(
                    evaluationContext: ImmutableContext(attributes: attributes))
            }
        }

        // An `And` step whose primary keyword is When. Untyped in the Gherkin, a string here.
        when(EvaluationPatterns.untypedFlagValue) { matches, _ in
            let state = ScenarioState.current
            state.flagKey = capture(matches, 1)
            state.stringValue = OpenFeatureAPI.shared.getClient().getStringValue(
                key: capture(matches, 1), defaultValue: capture(matches, 2))
        }

        then(EvaluationPatterns.stringResponse) { matches, _ in
            XCTAssertEqual(ScenarioState.current.stringValue, capture(matches, 1))
        }

        then(EvaluationPatterns.emptyContextValue) { matches, _ in
            guard let flagKey = ScenarioState.current.flagKey else {
                XCTFail("no flag was evaluated earlier in this scenario")
                return
            }
            AsyncBridge.run {
                await OpenFeatureAPI.shared.setEvaluationContextAndWait(
                    evaluationContext: ImmutableContext())
            }
            // A sentinel default, so the assertion cannot pass by falling back.
            XCTAssertEqual(
                OpenFeatureAPI.shared.getClient().getStringValue(
                    key: flagKey, defaultValue: "<unset>"),
                capture(matches, 1))
        }
    }
}
