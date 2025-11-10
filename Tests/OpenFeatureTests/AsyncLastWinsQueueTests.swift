import XCTest
@testable import OpenFeature

class AsyncLastWinsQueueTests: XCTestCase {
    func testSingleOperationExecutes() async throws {
        let queue = AsyncLastWinsQueue()
        let executed = ActorBox<Bool>(false)

        await queue.run {
            await executed.set(true)
        }

        let result = await executed.get()
        XCTAssertTrue(result, "Single operation should execute")
    }

    func testSequentialOperationsAllExecute() async throws {
        let queue = AsyncLastWinsQueue()
        let counter = ActorBox<Int>(0)

        // Execute 3 operations sequentially (one at a time)
        await queue.run {
            await counter.increment()
        }

        await queue.run {
            await counter.increment()
        }

        await queue.run {
            await counter.increment()
        }

        let result = await counter.get()
        XCTAssertEqual(result, 3, "All sequential operations should execute")
    }

    // MARK: - Core "Last Wins" Tests

    func testConcurrentOperationsSkipIntermediate() async throws {
        let queue = AsyncLastWinsQueue()
        let executionOrder = ActorBox<[Int]>([])
        let blockFirstOperation = ActorBox<Bool>(true)

        // Start 5 operations concurrently
        // The first one will block, the middle ones should be skipped,
        // only the last one should execute after the first completes
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<5 {
                group.addTask {
                    await queue.run {
                        // First operation blocks until we release it
                        if i == 0 {
                            while await blockFirstOperation.get() {
                                try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
                            }
                        }
                        await executionOrder.append(i)
                    }
                }
            }

            // Give time for all operations to be queued
            try? await Task.sleep(nanoseconds: 50_000_000) // 50ms

            // Release the first operation
            await blockFirstOperation.set(false)
        }

        let order = await executionOrder.get()

        // Should execute: operation 0 (first, was running) and operation 4 (last wins)
        XCTAssertEqual(order.count, 2, "Should only execute 2 operations: first and last")
        XCTAssertEqual(order[0], 0, "First operation should execute first")
        XCTAssertEqual(order[1], 4, "Last operation should execute second")
    }

    func testRapidFireOnlyExecutesFirstAndLast() async throws {
        let queue = AsyncLastWinsQueue()
        let executed = ActorBox<Set<Int>>([])

        await withTaskGroup(of: Void.self) { group in
            // Launch 100 operations that all try to start simultaneously
            for i in 0..<100 {
                group.addTask {
                    await queue.run {
                        // Simulate some work
                        try? await Task.sleep(nanoseconds: 1_000_000) // 1ms
                        await executed.insert(i)
                    }
                }
            }
        }

        let executedSet = await executed.get()

        // Should execute much fewer than 100 operations
        XCTAssertLessThan(executedSet.count, 100, "Should skip many intermediate operations")

        // First operation should execute (it started immediately)
        XCTAssertTrue(executedSet.contains(0), "First operation should execute")

        // Last operation should execute (last wins)
        XCTAssertTrue(executedSet.contains(99), "Last operation should execute")

        // Total executed should be small (first + maybe a few more + last)
        XCTAssertLessThan(executedSet.count, 10, "Should execute very few operations in rapid fire")
    }

    // MARK: - Ordering and Consistency Tests

    func testOperationsNeverRunConcurrently() async throws {
        let queue = AsyncLastWinsQueue()
        let concurrentExecutions = ActorBox<Int>(0)
        let maxConcurrent = ActorBox<Int>(0)
        let errors = ActorBox<[String]>([])

        await withTaskGroup(of: Void.self) { group in
            for i in 0..<50 {
                group.addTask {
                    await queue.run {
                        let current = await concurrentExecutions.increment()

                        if current > 1 {
                            await errors.append("Concurrent execution detected at operation \(i)")
                        }

                        await maxConcurrent.updateMax(current)

                        // Simulate work
                        try? await Task.sleep(nanoseconds: 5_000_000) // 5ms

                        await concurrentExecutions.decrement()
                    }
                }
            }
        }

        let max = await maxConcurrent.get()
        let errorList = await errors.get()

        XCTAssertEqual(max, 1, "Should never have more than 1 concurrent execution")
        XCTAssertTrue(errorList.isEmpty, "Should have no concurrent execution errors: \(errorList)")
    }

    func testFinalStateReflectsLastOperation() async throws {
        let queue = AsyncLastWinsQueue()
        let finalValue = ActorBox<String?>(nil)
        let slowOperationStarted = ActorBox<Bool>(false)
        let slowOperationCanProceed = ActorBox<Bool>(false)

        await withTaskGroup(of: Void.self) { group in
            // Start a slow operation
            group.addTask {
                await queue.run {
                    await slowOperationStarted.set(true)
                    // Wait for signal
                    while !(await slowOperationCanProceed.get()) {
                        try? await Task.sleep(nanoseconds: 10_000_000)
                    }
                    await finalValue.set("slow")
                }
            }

            // Wait for slow operation to start
            while !(await slowOperationStarted.get()) {
                try? await Task.sleep(nanoseconds: 10_000_000)
            }

            // Queue multiple operations while slow one is running
            group.addTask {
                await queue.run {
                    await finalValue.set("middle1")
                }
            }

            group.addTask {
                await queue.run {
                    await finalValue.set("middle2")
                }
            }

            group.addTask {
                await queue.run {
                    await finalValue.set("last")
                }
            }

            // Give time for all to be queued
            try? await Task.sleep(nanoseconds: 50_000_000)

            // Release slow operation
            await slowOperationCanProceed.set(true)
        }

        let result = await finalValue.get()
        XCTAssertEqual(result, "last", "Final state should reflect the last queued operation")
    }
}

// MARK: - Helper Actor for Thread-Safe State

actor ActorBox<T> {
    private var value: T

    init(_ initialValue: T) {
        self.value = initialValue
    }

    func get() -> T {
        return value
    }

    func set(_ newValue: T) {
        self.value = newValue
    }
}

extension ActorBox where T == Int {
    @discardableResult
    func increment() -> Int {
        value += 1
        return value
    }

    func decrement() {
        value -= 1
    }

    func updateMax(_ candidate: Int) {
        if candidate > value {
            value = candidate
        }
    }
}

extension ActorBox where T == [Int] {
    func append(_ element: Int) {
        value.append(element)
    }
}

extension ActorBox where T == [String] {
    func append(_ element: String) {
        value.append(element)
    }
}

extension ActorBox where T == Set<Int> {
    func insert(_ element: Int) {
        value.insert(element)
    }
}
