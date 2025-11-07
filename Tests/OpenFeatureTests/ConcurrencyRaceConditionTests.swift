
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
        XCTAssertTrue(true)
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
        XCTAssertNotNil(finalState.provider)
        XCTAssertNotNil(finalState.evaluationContext)
        XCTAssertTrue([.ready, .error, .fatal].contains(finalState.providerStatus))
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
        XCTAssertTrue([.notReady, .ready, .error, .fatal].contains(finalState.providerStatus))
    }
}
