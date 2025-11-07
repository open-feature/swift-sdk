
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
                            "timestamp": .string("\(Date().timeIntervalSince1970)")
                        ])
                    )
                    
                    // This should trigger the race condition in updateContext
                    await OpenFeatureAPI.shared.setEvaluationContextAndWait(evaluationContext: ctx)
                }
            }
        }
        
        cancellable.cancel()
        
        // Verify final state is consistent and correct
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

    /// Test the specific race condition between setProvider and setEvaluationContext
    /// This was the main issue identified by the external reviewer
    func testSetProviderVsSetEvaluationContextRaceCondition() async throws {
        let concurrentOperations = 50

        await withTaskGroup(of: Void.self) { group in
            // Concurrently set providers and evaluation contexts
            for i in 0..<concurrentOperations {
                // Set provider operations
                group.addTask {
                    let provider = MockProvider()
                    let ctx = ImmutableContext(
                        targetingKey: "provider-user\(i)",
                        structure: ImmutableStructure(attributes: ["provider": .integer(Int64(i))])
                    )
                    await OpenFeatureAPI.shared.setProviderAndWait(provider: provider, initialContext: ctx)
                }

                // Set evaluation context operations
                group.addTask {
                    let ctx = ImmutableContext(
                        targetingKey: "context-user\(i)",
                        structure: ImmutableStructure(attributes: ["context": .integer(Int64(i))])
                    )
                    await OpenFeatureAPI.shared.setEvaluationContextAndWait(evaluationContext: ctx)
                }
            }
        }

        // Verify the API is in a consistent state
        let finalState = OpenFeatureAPI.shared.getState()
        XCTAssertNotNil(finalState.provider, "Provider should not be nil after concurrent operations")
        XCTAssertNotNil(finalState.evaluationContext, "Evaluation context should not be nil after concurrent operations")
        XCTAssertTrue([.ready, .error, .fatal].contains(finalState.providerStatus), "Provider status should be in a valid final state")
        
        // Verify the final context has expected structure from one of the operations
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

    /// Test the race condition between provider initialization and context updates
    func testProviderInitializationVsContextUpdateRaceCondition() async throws {
        let concurrentOperations = 30

        await withTaskGroup(of: Void.self) { group in
            for i in 0..<concurrentOperations {
                // Provider initialization with context
                group.addTask {
                    let provider = MockProvider()
                    let initialCtx = ImmutableContext(
                        targetingKey: "init-user\(i)",
                        structure: ImmutableStructure(attributes: ["init": .integer(Int64(i))])
                    )
                    await OpenFeatureAPI.shared.setProviderAndWait(provider: provider, initialContext: initialCtx)
                }

                // Immediate context updates
                group.addTask {
                    let updateCtx = ImmutableContext(
                        targetingKey: "update-user\(i)",
                        structure: ImmutableStructure(attributes: ["update": .integer(Int64(i))])
                    )
                    await OpenFeatureAPI.shared.setEvaluationContextAndWait(evaluationContext: updateCtx)
                }

                // Clear provider operations
                group.addTask {
                    OpenFeatureAPI.shared.clearProvider()
                }
            }
        }

        // Verify the API ends in a consistent state
        let finalState = OpenFeatureAPI.shared.getState()
        XCTAssertTrue([.notReady, .ready, .error, .fatal].contains(finalState.providerStatus))
    }

    /// Test high-frequency state changes to stress test synchronization
    func testHighFrequencyStateChangesRaceCondition() async throws {
        let highFrequencyOperations = 200
        let startTime = Date()

        await withTaskGroup(of: Void.self) { group in
            for i in 0..<highFrequencyOperations {
                group.addTask {
                    // Rapid fire operations
                    let provider = MockProvider()
                    let ctx = ImmutableContext(
                        targetingKey: "rapid-user\(i)",
                        structure: ImmutableStructure(attributes: [
                            "iteration": .integer(Int64(i)),
                            "timestamp": .string("\(Date().timeIntervalSince1970)")
                        ])
                    )

                    // Alternate between different operations
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

        // Verify final state is consistent
        let finalState = OpenFeatureAPI.shared.getState()
        XCTAssertTrue(
            [ProviderStatus.notReady, .ready, .error, .fatal].contains(finalState.providerStatus),
            "Provider status '\(finalState.providerStatus)' should be in a valid state after high-frequency operations"
        )
        
        // If we have a provider and context, verify they're consistent
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
        }
    }
}
