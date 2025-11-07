import XCTest
import Combine
@testable import OpenFeature

class ConcurrencyRaceConditionTests: XCTestCase {
    override func setUp() {
        super.setUp()
        OpenFeatureAPI.shared.clearProvider()
    }

    func testConcurrentSetEvaluationContextRaceCondition() async throws {
        let provider = MockProvider()
        let readyExpectation = XCTestExpectation(description: "Ready")
        let cancellable = OpenFeatureAPI.shared.observe().sink { event in
            if case .ready = event {
                readyExpectation.fulfill()
            }
        }
        OpenFeatureAPI.shared.setProvider(provider: provider)
        await fulfillment(of: [readyExpectation], timeout: 2.0)

        let concurrentOperations = 100
        let expectedTargetingKeys = Set((0..<concurrentOperations).map { "user\($0)" })

        await withTaskGroup(of: Void.self) { group in
            for i in 0..<concurrentOperations {
                group.addTask {
                    let ctx = ImmutableContext(
                        targetingKey: "user\(i)",
                        structure: ImmutableStructure(attributes: [
                            "id": .integer(Int64(i)),
                            "timestamp": .string("\(Date().timeIntervalSince1970)"),
                        ])
                    )

                    await OpenFeatureAPI.shared.setEvaluationContextAndWait(evaluationContext: ctx)
                }
            }
        }

        cancellable.cancel()

        let finalContext = OpenFeatureAPI.shared.getEvaluationContext()
        XCTAssertNotNil(finalContext, "Final evaluation context should not be nil after concurrent operations")

        if let context = finalContext {
            let targetingKey = context.getTargetingKey()
            XCTAssertTrue(
                expectedTargetingKeys.contains(targetingKey),
                "Final targeting key '\(targetingKey)' should be one of the expected keys from concurrent operations"
            )

            let contextMap = context.asObjectMap()
            XCTAssertTrue(contextMap.keys.contains("id"), "Context should contain 'id' attribute")
            XCTAssertTrue(contextMap.keys.contains("timestamp"), "Context should contain 'timestamp' attribute")

            if let idValue = contextMap["id"] as? Int64 {
                let expectedId = Int64(targetingKey.replacingOccurrences(of: "user", with: ""))!
                XCTAssertEqual(idValue, expectedId, "Context 'id' should match the targeting key number")
            } else {
                XCTFail("Context 'id' should be an Int64 value")
            }
        }
    }

    func testSetProviderVsSetEvaluationContextRaceCondition() async throws {
        let concurrentOperations = 50

        await withTaskGroup(of: Void.self) { group in
            for i in 0..<concurrentOperations {
                group.addTask {
                    let provider = MockProvider()
                    let ctx = ImmutableContext(
                        targetingKey: "provider-user\(i)",
                        structure: ImmutableStructure(attributes: ["provider": .integer(Int64(i))])
                    )
                    await OpenFeatureAPI.shared.setProviderAndWait(provider: provider, initialContext: ctx)
                }

                group.addTask {
                    let ctx = ImmutableContext(
                        targetingKey: "context-user\(i)",
                        structure: ImmutableStructure(attributes: ["context": .integer(Int64(i))])
                    )
                    await OpenFeatureAPI.shared.setEvaluationContextAndWait(evaluationContext: ctx)
                }
            }
        }

        let finalState = OpenFeatureAPI.shared.getState()
        XCTAssertNotNil(finalState.provider, "Provider should not be nil after concurrent operations")
        XCTAssertNotNil(finalState.evaluationContext, "Evaluation context should not be nil after concurrent operations")
        XCTAssertTrue([.ready].contains(finalState.providerStatus), "Provider status should be in a valid final state")

        if let context = finalState.evaluationContext {
            let targetingKey = context.getTargetingKey()
            XCTAssertTrue(
                targetingKey.hasPrefix("provider-user") || targetingKey.hasPrefix("context-user"),
                "Final targeting key '\(targetingKey)' should be from one of the concurrent operations"
            )

            let contextMap = context.asObjectMap()
            let hasProviderAttribute = contextMap.keys.contains("provider")
            let hasContextAttribute = contextMap.keys.contains("context")
            XCTAssertTrue(
                hasProviderAttribute || hasContextAttribute,
                "Context should contain either 'provider' or 'context' attribute from the operations"
            )
        }
    }

    func testHighFrequencyStateChangesRaceCondition() async throws {
        let highFrequencyOperations = 200
        let startTime = Date()

        await withTaskGroup(of: Void.self) { group in
            for i in 0..<highFrequencyOperations {
                group.addTask {
                    let provider = MockProvider()
                    let ctx = ImmutableContext(
                        targetingKey: "rapid-user\(i)",
                        structure: ImmutableStructure(attributes: [
                            "iteration": .integer(Int64(i)),
                            "timestamp": .string("\(Date().timeIntervalSince1970)"),
                        ])
                    )
                    switch i % 4 {
                    case 0:
                        await OpenFeatureAPI.shared.setProviderAndWait(provider: provider)
                    case 1:
                        await OpenFeatureAPI.shared.setEvaluationContextAndWait(evaluationContext: ctx)
                    case 2:
                        await OpenFeatureAPI.shared.setProviderAndWait(provider: provider, initialContext: ctx)
                    case 3:
                        OpenFeatureAPI.shared.clearProvider()
                    default:
                        break
                    }
                }
            }
        }

        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)

        // Verify operations completed in reasonable time (no deadlocks)
        XCTAssertLessThan(duration, 10.0, "Operations took too long, possible deadlock")

        let finalState = OpenFeatureAPI.shared.getState()
        XCTAssertTrue(
            [ProviderStatus.ready].contains(finalState.providerStatus),
            "Provider status '\(finalState.providerStatus)' should be in a valid state after high-frequency operations"
        )
        if finalState.provider != nil && finalState.evaluationContext != nil {
            let context = finalState.evaluationContext!
            let targetingKey = context.getTargetingKey()
            XCTAssertTrue(
                targetingKey.hasPrefix("rapid-user"),
                "Final targeting key '\(targetingKey)' should be from the rapid operations if context exists"
            )

            let contextMap = context.asObjectMap()
            if contextMap.keys.contains("iteration") {
                XCTAssertTrue(contextMap.keys.contains("timestamp"), "Context with iteration should also have timestamp")
            }
        } else {
            XCTFail()
        }
    }
}
