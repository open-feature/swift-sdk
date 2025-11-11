import Foundation

/// Unified serial async task queue with operation-type-aware last-wins semantics.
/// - Non-last-wins operations always execute in order
/// - Consecutive last-wins operations: only the last one executes
/// - Order is always preserved
internal actor AsyncProviderOperationsQueue {
    private var currentTask: Task<Void, Never>?

    private struct QueuedOperation {
        let operation: () async -> Void
        let continuation: CheckedContinuation<Void, Never>
        let lastWins: Bool
    }

    private var queue: [QueuedOperation] = []

    /// Runs the given operation serially.
    /// - If lastWins is false: operation always executes
    /// - If lastWins is true: may be skipped if superseded by a later last-wins operation
    func run(lastWins: Bool, operation: @Sendable @escaping () async -> Void) async {
        await withCheckedContinuation { continuation in
            queue.append(QueuedOperation(operation: operation, continuation: continuation, lastWins: lastWins))

            if currentTask == nil {
                processNext()
            }
        }
    }

    private func processNext() {
        guard !queue.isEmpty else {
            currentTask = nil
            return
        }

        // Find the next batch to execute
        // A batch is either:
        // 1. A single non-last-wins operation, OR
        // 2. Consecutive last-wins operations (we execute only the last one)

        let firstOp = queue[0]

        if !firstOp.lastWins {
            // Non-last-wins operation: execute it immediately
            let op = queue.removeFirst()
            currentTask = Task { [weak self] in
                await op.operation()
                op.continuation.resume()
                await self?.processNext()
            }
        } else {
            // Last-wins operation: find all consecutive last-wins ops
            var lastWinsCount = 0
            for op in queue {
                if op.lastWins {
                    lastWinsCount += 1
                } else {
                    break
                }
            }

            // Execute only the last one in the last-wins batch
            let toSkip = Array(queue.prefix(lastWinsCount - 1))
            let toExecute = queue[lastWinsCount - 1]
            queue.removeFirst(lastWinsCount)

            currentTask = Task { [weak self] in
                await toExecute.operation()

                // Resume all continuations (both skipped and executed)
                for op in toSkip {
                    op.continuation.resume()
                }
                toExecute.continuation.resume()

                await self?.processNext()
            }
        }
    }
}
