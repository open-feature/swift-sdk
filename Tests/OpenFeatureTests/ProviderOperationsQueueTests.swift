import XCTest
import Combine
@testable import OpenFeature

// swiftlint:disable type_body_length file_length trailing_closure
class ProviderOperationsQueueTests: XCTestCase {
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
        XCTAssertNotNil(
            finalState.evaluationContext,
            "Evaluation context should not be nil after concurrent operations"
        )
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

    func testHighFrequencyStateChangesWithFinalClearProvider() async throws {
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
        // Note: Since operations now execute in order and the last operation (i=199, 199%4=3) is clearProvider(),
        // the final state will have notReady status and nil provider
        XCTAssertTrue(
            [ProviderStatus.notReady].contains(finalState.providerStatus),
            "Provider status '\(finalState.providerStatus)' should be in a valid state after high-frequency operations"
        )
        XCTAssertNil(finalState.provider)
        let context = finalState.evaluationContext
        let targetingKey = context?.getTargetingKey() ?? ""
        XCTAssertTrue(
            targetingKey.hasPrefix("rapid-user"),
            "Final targeting key '\(targetingKey)' should be from the rapid operations if context exists"
        )

        let contextMap = context?.asObjectMap() ?? [:]
        if contextMap.keys.contains("iteration") {
            XCTAssertTrue(
                contextMap.keys.contains("timestamp"),
                "Context with iteration should also have timestamp"
            )
        }
    }

    // swiftlint:disable:next function_body_length
    func testAsyncCoalescingSerialQueueCoalescence() async throws {
        // Track which operations actually executed
        actor ExecutionTracker {
            var executedOperations: [String] = []

            func recordExecution(_ operation: String) {
                executedOperations.append(operation)
            }

            func getExecutions() -> [String] {
                return executedOperations
            }
        }

        let tracker = ExecutionTracker()

        // Create a provider with a slow onContextSet to ensure operations overlap
        let provider = MockProvider(
            onContextSet: { _, newContext in
                // Add delay to simulate slow provider operation
                // This ensures that when tasks 2 and 3 are queued, task 1 is still running
                let targetingKey = newContext.getTargetingKey()
                await tracker.recordExecution(targetingKey)
                try await Task.sleep(nanoseconds: 200_000_000) // 200ms
            }
        )

        // Set up provider first
        await OpenFeatureAPI.shared.setProviderAndWait(provider: provider)

        // Start three concurrent context updates
        async let task1: Void = {
            let ctx1 = ImmutableContext(
                targetingKey: "user1",
                structure: ImmutableStructure(attributes: ["id": .integer(1)])
            )
            await OpenFeatureAPI.shared.setEvaluationContextAndWait(evaluationContext: ctx1)
        }()

        // Small delay to ensure task1 starts first
        try await Task.sleep(nanoseconds: 10_000_000) // 10ms

        async let task2: Void = {
            let ctx2 = ImmutableContext(
                targetingKey: "user2",
                structure: ImmutableStructure(attributes: ["id": .integer(2)])
            )
            await OpenFeatureAPI.shared.setEvaluationContextAndWait(evaluationContext: ctx2)
        }()

        // Small delay to ensure task2 starts before task3
        try await Task.sleep(nanoseconds: 10_000_000) // 10ms

        async let task3: Void = {
            let ctx3 = ImmutableContext(
                targetingKey: "user3",
                structure: ImmutableStructure(attributes: ["id": .integer(3)])
            )
            await OpenFeatureAPI.shared.setEvaluationContextAndWait(evaluationContext: ctx3)
        }()

        // Wait for all tasks to complete
        await task1
        await task2
        await task3

        let executedOperations = await tracker.getExecutions()

        // Verify coalescence: if working correctly, should have executed at most 2 operations
        // (first one + latest one), skipping the middle one
        XCTAssertLessThanOrEqual(
            executedOperations.count,
            2,
            """
            Should execute at most 2 operations due to coalescence (first + latest), \
            but executed: \(executedOperations)
            """
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

    // MARK: - Edge Case Tests for AsyncCoalescingSerialQueue Coalescence

    func testAsyncCoalescingSerialQueueSingleOperation() async throws {
        // Test that a single operation executes normally without coalescence
        actor ExecutionTracker {
            var executedOperations: [String] = []
            func recordExecution(_ operation: String) {
                executedOperations.append(operation)
            }
            func getExecutions() -> [String] { executedOperations }
        }

        let tracker = ExecutionTracker()
        let provider = MockProvider(
            onContextSet: { _, newContext in
                await tracker.recordExecution(newContext.getTargetingKey())
            }
        )

        await OpenFeatureAPI.shared.setProviderAndWait(provider: provider)

        let ctx = ImmutableContext(
            targetingKey: "single-user",
            structure: ImmutableStructure(attributes: ["id": .integer(1)])
        )
        await OpenFeatureAPI.shared.setEvaluationContextAndWait(evaluationContext: ctx)

        let executedOperations = await tracker.getExecutions()
        XCTAssertEqual(executedOperations.count, 1, "Single operation should execute exactly once")
        XCTAssertEqual(executedOperations.first, "single-user", "Should execute the single operation")
        XCTAssertEqual(OpenFeatureAPI.shared.getEvaluationContext()?.getTargetingKey(), "single-user")
    }

    func testAsyncCoalescingSerialQueueTwoSequentialOperations() async throws {
        // Test two operations that don't overlap - both should execute
        actor ExecutionTracker {
            var executedOperations: [String] = []
            func recordExecution(_ operation: String) {
                executedOperations.append(operation)
            }
            func getExecutions() -> [String] { executedOperations }
        }

        let tracker = ExecutionTracker()
        let provider = MockProvider(
            onContextSet: { _, newContext in
                await tracker.recordExecution(newContext.getTargetingKey())
                try await Task.sleep(nanoseconds: 10_000_000) // 10ms
            }
        )

        await OpenFeatureAPI.shared.setProviderAndWait(provider: provider)

        // First operation
        let ctx1 = ImmutableContext(
            targetingKey: "user1",
            structure: ImmutableStructure(attributes: ["id": .integer(1)])
        )
        await OpenFeatureAPI.shared.setEvaluationContextAndWait(evaluationContext: ctx1)

        // Second operation - starts after first completes
        let ctx2 = ImmutableContext(
            targetingKey: "user2",
            structure: ImmutableStructure(attributes: ["id": .integer(2)])
        )
        await OpenFeatureAPI.shared.setEvaluationContextAndWait(evaluationContext: ctx2)

        let executedOperations = await tracker.getExecutions()
        XCTAssertEqual(executedOperations.count, 2, "Both sequential operations should execute")
        XCTAssertEqual(executedOperations, ["user1", "user2"], "Operations should execute in order")
        XCTAssertEqual(OpenFeatureAPI.shared.getEvaluationContext()?.getTargetingKey(), "user2")
    }

    func testAsyncCoalescingSerialQueueRapidBurstCoalescence() async throws {
        // Test that rapid bursts of many operations get heavily coalesced
        actor ExecutionTracker {
            var executedOperations: [String] = []
            func recordExecution(_ operation: String) {
                executedOperations.append(operation)
            }
            func getExecutions() -> [String] { executedOperations }
        }

        let tracker = ExecutionTracker()
        let provider = MockProvider(
            onContextSet: { _, newContext in
                await tracker.recordExecution(newContext.getTargetingKey())
                try await Task.sleep(nanoseconds: 100_000_000) // 100ms - long enough for many to queue
            }
        )

        await OpenFeatureAPI.shared.setProviderAndWait(provider: provider)

        // Launch 10 operations rapidly
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<10 {
                group.addTask {
                    let ctx = ImmutableContext(
                        targetingKey: "user\(i)",
                        structure: ImmutableStructure(attributes: ["id": .integer(Int64(i))])
                    )
                    await OpenFeatureAPI.shared.setEvaluationContextAndWait(evaluationContext: ctx)
                }
            }
        }

        let executedOperations = await tracker.getExecutions()

        // Should execute far fewer than 10 operations due to coalescence
        XCTAssertLessThanOrEqual(
            executedOperations.count,
            3,
            "Rapid burst should heavily coalesce, executed: \(executedOperations)"
        )

        // Final context should be from one of the last operations
        let finalContext = OpenFeatureAPI.shared.getEvaluationContext()
        let finalKey = finalContext?.getTargetingKey() ?? ""
        XCTAssertTrue(
            finalKey.hasPrefix("user"),
            "Final context should be from one of the operations"
        )
    }

    func testAsyncCoalescingSerialQueueOperationsArrivingAfterCompletion() async throws {
        // Test that operations arriving after the previous one completes still execute
        actor ExecutionTracker {
            var executedOperations: [String] = []
            func recordExecution(_ operation: String) {
                executedOperations.append(operation)
            }
            func getExecutions() -> [String] { executedOperations }
        }

        let tracker = ExecutionTracker()
        let provider = MockProvider(
            onContextSet: { _, newContext in
                await tracker.recordExecution(newContext.getTargetingKey())
            }
        )

        await OpenFeatureAPI.shared.setProviderAndWait(provider: provider)

        // First operation
        let ctx1 = ImmutableContext(
            targetingKey: "batch1-user1",
            structure: ImmutableStructure(attributes: ["id": .integer(1)])
        )
        await OpenFeatureAPI.shared.setEvaluationContextAndWait(evaluationContext: ctx1)

        // Wait a bit to ensure first operation is completely done
        try await Task.sleep(nanoseconds: 50_000_000) // 50ms

        // Now submit several operations that arrive after the queue is idle
        async let task2: Void = {
            let ctx2 = ImmutableContext(
                targetingKey: "batch2-user2",
                structure: ImmutableStructure(attributes: ["id": .integer(2)])
            )
            await OpenFeatureAPI.shared.setEvaluationContextAndWait(evaluationContext: ctx2)
        }()

        try await Task.sleep(nanoseconds: 5_000_000) // 5ms

        async let task3: Void = {
            let ctx3 = ImmutableContext(
                targetingKey: "batch2-user3",
                structure: ImmutableStructure(attributes: ["id": .integer(3)])
            )
            await OpenFeatureAPI.shared.setEvaluationContextAndWait(evaluationContext: ctx3)
        }()

        await task2
        await task3

        let executedOperations = await tracker.getExecutions()

        // Should have first operation, and at least one from the second batch
        XCTAssertGreaterThanOrEqual(executedOperations.count, 2, "Should execute operations from both batches")
        XCTAssertEqual(executedOperations.first, "batch1-user1", "First operation should execute")

        let finalContext = OpenFeatureAPI.shared.getEvaluationContext()
        XCTAssertTrue(
            finalContext?.getTargetingKey().hasPrefix("batch2") ?? false,
            "Final context should be from second batch"
        )
    }

    func testAsyncCoalescingSerialQueueWithErrorHandling() async throws {
        // Test that errors in operations don't break the queue
        actor ExecutionTracker {
            var executedOperations: [String] = []
            var errorOccurred = false
            func recordExecution(_ operation: String) {
                executedOperations.append(operation)
            }
            func recordError() {
                errorOccurred = true
            }
            func getExecutions() -> [String] { executedOperations }
            func hasError() -> Bool { errorOccurred }
        }

        let tracker = ExecutionTracker()
        let provider = MockProvider(
            onContextSet: { _, newContext in
                let targetingKey = newContext.getTargetingKey()
                await tracker.recordExecution(targetingKey)

                // Throw error for "error-user"
                if targetingKey == "error-user" {
                    await tracker.recordError()
                    throw MockProvider.MockProviderError.message("Simulated error")
                }

                try await Task.sleep(nanoseconds: 200_000_000) // 200ms
            }
        )

        await OpenFeatureAPI.shared.setProviderAndWait(provider: provider)

        // Launch operations including one that will error
        async let task1: Void = {
            let ctx1 = ImmutableContext(
                targetingKey: "user1",
                structure: ImmutableStructure(attributes: ["id": .integer(1)])
            )
            await OpenFeatureAPI.shared.setEvaluationContextAndWait(evaluationContext: ctx1)
        }()

        try await Task.sleep(nanoseconds: 10_000_000) // 10ms

        async let task2: Void = {
            let ctx2 = ImmutableContext(
                targetingKey: "error-user",
                structure: ImmutableStructure(attributes: ["id": .integer(2)])
            )
            await OpenFeatureAPI.shared.setEvaluationContextAndWait(evaluationContext: ctx2)
        }()

        try await Task.sleep(nanoseconds: 10_000_000) // 10ms

        async let task3: Void = {
            let ctx3 = ImmutableContext(
                targetingKey: "user3",
                structure: ImmutableStructure(attributes: ["id": .integer(3)])
            )
            await OpenFeatureAPI.shared.setEvaluationContextAndWait(evaluationContext: ctx3)
        }()

        await task1
        await task2
        await task3

        let executedOperations = await tracker.getExecutions()

        // Should execute at most 2 operations due to coalescence
        XCTAssertLessThanOrEqual(executedOperations.count, 2, "Should coalesce despite errors")

        // Final context depends on which operations were coalesced
        // But the queue should still be functional
        let finalContext = OpenFeatureAPI.shared.getEvaluationContext()
        XCTAssertNotNil(finalContext, "Queue should continue functioning after error")

        // Provider status should reflect the error
        let status = OpenFeatureAPI.shared.getProviderStatus()
        XCTAssertTrue(
            [.ready, .error].contains(status),
            "Status should be either ready or error depending on final operation"
        )
    }

    func testAsyncCoalescingSerialQueueContinuationResumeCorrectness() async throws {
        // Test that all callers get resumed correctly, even those whose operations were skipped
        actor CompletionTracker {
            var completedTasks: Set<Int> = []
            func markCompleted(_ taskId: Int) {
                completedTasks.insert(taskId)
            }
            func getCompleted() -> Set<Int> { completedTasks }
        }

        let completionTracker = CompletionTracker()
        let provider = MockProvider(
            onContextSet: { _, _ in
                try await Task.sleep(nanoseconds: 50_000_000) // 50ms
            }
        )

        await OpenFeatureAPI.shared.setProviderAndWait(provider: provider)

        // Launch multiple tasks and track that they all complete
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<5 {
                group.addTask {
                    let ctx = ImmutableContext(
                        targetingKey: "user\(i)",
                        structure: ImmutableStructure(attributes: ["id": .integer(Int64(i))])
                    )
                    await OpenFeatureAPI.shared.setEvaluationContextAndWait(evaluationContext: ctx)
                    await completionTracker.markCompleted(i)
                }

                // Small stagger to ensure they overlap
                try? await Task.sleep(nanoseconds: 5_000_000) // 5ms
            }
        }

        let completedTasks = await completionTracker.getCompleted()

        // All 5 tasks should have completed (received their continuation resume)
        XCTAssertEqual(
            completedTasks.count,
            5,
            "All tasks should complete even if their operations were coalesced"
        )
        XCTAssertEqual(
            completedTasks,
            Set([0, 1, 2, 3, 4]),
            "All task IDs should be marked as completed"
        )
    }

    func testAsyncCoalescingSerialQueueNoStarvation() async throws {
        // Test that the queue doesn't cause starvation - operations eventually execute
        actor ExecutionTracker {
            var executedOperations: [String] = []
            func recordExecution(_ operation: String) {
                executedOperations.append(operation)
            }
            func getExecutions() -> [String] { executedOperations }
        }

        let tracker = ExecutionTracker()
        let provider = MockProvider(
            onContextSet: { _, newContext in
                await tracker.recordExecution(newContext.getTargetingKey())
                try await Task.sleep(nanoseconds: 20_000_000) // 20ms
            }
        )

        await OpenFeatureAPI.shared.setProviderAndWait(provider: provider)

        // Submit operations in waves to test that later waves aren't starved
        for wave in 0..<3 {
            await withTaskGroup(of: Void.self) { group in
                for i in 0..<5 {
                    group.addTask {
                        let ctx = ImmutableContext(
                            targetingKey: "wave\(wave)-user\(i)",
                            structure: ImmutableStructure(attributes: [
                                "wave": .integer(Int64(wave)),
                                "id": .integer(Int64(i)),
                            ])
                        )
                        await OpenFeatureAPI.shared.setEvaluationContextAndWait(evaluationContext: ctx)
                    }
                }
            }

            // Small delay between waves
            try await Task.sleep(nanoseconds: 30_000_000) // 30ms
        }

        let executedOperations = await tracker.getExecutions()

        // Should have executed at least one operation from each wave
        let hasWave0 = executedOperations.contains { $0.hasPrefix("wave0") }
        let hasWave1 = executedOperations.contains { $0.hasPrefix("wave1") }
        let hasWave2 = executedOperations.contains { $0.hasPrefix("wave2") }

        XCTAssertTrue(hasWave0, "Should execute operations from wave 0")
        XCTAssertTrue(hasWave1, "Should execute operations from wave 1")
        XCTAssertTrue(hasWave2, "Should execute operations from wave 2")

        // Final context should be from the last wave
        let finalContext = OpenFeatureAPI.shared.getEvaluationContext()
        XCTAssertTrue(
            finalContext?.getTargetingKey().hasPrefix("wave2") ?? false,
            "Final context should be from the last wave"
        )
    }
}
// swiftlint:enable type_body_length file_length trailing_closure
