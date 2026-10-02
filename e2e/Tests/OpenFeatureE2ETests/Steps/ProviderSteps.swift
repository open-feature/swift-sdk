import CucumberSwift
import Foundation
import OpenFeature
import XCTest

extension Cucumber {
    @available(*, deprecated, message: "See StepRegistration.swift")
    func registerLifecycleHooks() {
        BeforeScenario { _ in
            ScenarioState.clear()
        }
        AfterScenario { _ in
            OpenFeatureAPI.shared.clearProvider()
            // The evaluation context is global, so reset it here rather than relying on every
            // scenario's background step to overwrite it.
            OpenFeatureAPI.shared.setEvaluationContext(evaluationContext: ImmutableContext())
            ScenarioState.clear()
        }
    }

    @available(*, deprecated, message: "See StepRegistration.swift")
    func registerProviderSteps() {
        given(EvaluationPatterns.stableProvider) { _, _ in
            ScenarioState.reset()
            // The empty `initialContext` makes the suite order-independent: the evaluation
            // context is global, and one scenario mutates it.
            AsyncBridge.run {
                await OpenFeatureAPI.shared.setProviderAndWait(
                    provider: InMemoryProvider(flags: EvaluationFlags.all),
                    initialContext: ImmutableContext())
            }
            XCTAssertEqual(
                OpenFeatureAPI.shared.getProviderStatus(),
                .ready,
                "InMemoryProvider should be ready once setProviderAndWait returns")
        }
    }
}
