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
                let expectedId = Int64(targetingKey.replacingOccurrences(of: "user", with: ""))
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
            let context = finalState.evaluationContext
            let targetingKey = context?.getTargetingKey() ?? ""
            XCTAssertTrue(
                targetingKey.hasPrefix("rapid-user"),
                "Final targeting key '\(targetingKey)' should be from the rapid operations if context exists"
            )

            let contextMap = context?.asObjectMap() ?? [:]
            if contextMap.keys.contains("iteration") {
                XCTAssertTrue(contextMap.keys.contains("timestamp"), "Context with iteration should also have timestamp")
            }
        } else {
            XCTFail("Provider or Evaluation Context unexpectedly nil")
        }
    }

    func testAsyncSerialQueueCoalescence() async throws {
        print("\n========== AsyncSerialQueue Coalescence Test ==========\n")

        // Track which operations actually executed
        actor ExecutionTracker {
            var executedOperations: [String] = []

            func recordExecution(_ operation: String) {
                executedOperations.append(operation)
                print("📝 Recorded execution: \(operation)")
            }

            func getExecutions() -> [String] {
                return executedOperations
            }
        }

        let tracker = ExecutionTracker()

        // Create a provider with a slow onContextSet to ensure operations overlap
        let provider = MockProvider(
            onContextSet: { oldContext, newContext in
                // Add delay to simulate slow provider operation
                // This ensures that when tasks 2 and 3 are queued, task 1 is still running
                let targetingKey = newContext.getTargetingKey()
                print("⚙️  Provider.onContextSet running for: \(targetingKey)")
                await tracker.recordExecution(targetingKey)
                try await Task.sleep(nanoseconds: 50_000_000) // 50ms
                print("✓ Provider.onContextSet completed for: \(targetingKey)")
            }
        )

        // Set up provider first
        print("🔧 Setting up provider...")
        await OpenFeatureAPI.shared.setProviderAndWait(provider: provider)
        print("✅ Provider ready\n")

        // Start three concurrent context updates
        print("🚀 Starting three concurrent setEvaluationContext calls:\n")

        async let task1: Void = {
            print("🔵 Task 1: STARTING - Creating context for user1")
            let ctx1 = ImmutableContext(
                targetingKey: "user1",
                structure: ImmutableStructure(attributes: ["id": .integer(1)])
            )
            print("🔵 Task 1: CALLING setEvaluationContextAndWait(user1)")
            await OpenFeatureAPI.shared.setEvaluationContextAndWait(evaluationContext: ctx1)
            print("🔵 Task 1: RETURNED from setEvaluationContextAndWait")
            print("🔵 Task 1: COMPLETED\n")
        }()

        // Small delay to ensure task1 starts first
        try await Task.sleep(nanoseconds: 10_000_000) // 10ms

        async let task2: Void = {
            print("🟢 Task 2: STARTING - Creating context for user2")
            let ctx2 = ImmutableContext(
                targetingKey: "user2",
                structure: ImmutableStructure(attributes: ["id": .integer(2)])
            )
            print("🟢 Task 2: CALLING setEvaluationContextAndWait(user2)")
            await OpenFeatureAPI.shared.setEvaluationContextAndWait(evaluationContext: ctx2)
            print("🟢 Task 2: RETURNED from setEvaluationContextAndWait")
            print("🟢 Task 2: COMPLETED\n")
        }()

        // Small delay to ensure task2 starts before task3
        try await Task.sleep(nanoseconds: 10_000_000) // 10ms

        async let task3: Void = {
            print("🔴 Task 3: STARTING - Creating context for user3")
            let ctx3 = ImmutableContext(
                targetingKey: "user3",
                structure: ImmutableStructure(attributes: ["id": .integer(3)])
            )
            print("🔴 Task 3: CALLING setEvaluationContextAndWait(user3)")
            await OpenFeatureAPI.shared.setEvaluationContextAndWait(evaluationContext: ctx3)
            print("🔴 Task 3: RETURNED from setEvaluationContextAndWait")
            print("🔴 Task 3: COMPLETED\n")
        }()

        // Wait for all tasks to complete
        await task1
        await task2
        await task3

        let executedOperations = await tracker.getExecutions()

        print("========== RESULTS ==========")
        print("Operations that actually executed: \(executedOperations)")
        print("Total operations executed: \(executedOperations.count)")
        print("Expected: 2 operations (user1 and user3)")
        print("Expected skipped: user2 (replaced by user3)")
        print("========================================\n")

        // Verify coalescence: if working correctly, should have executed at most 2 operations
        // (first one + latest one), skipping the middle one
        XCTAssertLessThanOrEqual(
            executedOperations.count,
            2,
            "Should execute at most 2 operations due to coalescence (first + latest), but executed: \(executedOperations)"
        )

        // Verify user2 was NOT executed (it should be coalesced/skipped)
        XCTAssertFalse(
            executedOperations.contains("user2"),
            "user2 operation should have been skipped due to coalescence"
        )

        // Verify final context is from the last operation
        let finalContext = OpenFeatureAPI.shared.getEvaluationContext()
        XCTAssertEqual(
            finalContext?.getTargetingKey(),
            "user3",
            "Final context should be from the last operation (user3)"
        )
    }
}
