import Foundation

/// Simple serial async task queue that coalesces operations.
/// Only the currently running task and at most one pending operation are kept.
/// Intermediate operations are skipped to avoid queue buildup.
internal actor AsyncSerialQueue {
    private var currentTask: Task<Void, Never>?
    private var pendingOperation: (() async -> Void)?
    private var pendingContinuations: [CheckedContinuation<Void, Never>] = []
    private var operationCounter: Int = 0

    /// Verbose mode controls whether debug logging is enabled
    private let verbose: Bool

    /// Initialize the queue with optional verbose logging
    /// - Parameter verbose: If true, detailed debug logs will be printed with [ASQ] prefix
    init(verbose: Bool = false) {
        self.verbose = verbose
    }

    /// Runs the given operation serially. If an operation is already running,
    /// this operation replaces any previously pending operation (which gets skipped).
    /// All callers whose operations were replaced will wait for the latest operation to complete.
    func run(_ operation: @Sendable @escaping () async -> Void) async {
        await withCheckedContinuation { continuation in
            operationCounter += 1
            let operationId = operationCounter

            if verbose {
                print("[ASQ] 🔵 run() called - Operation #\(operationId)")
                print("[ASQ]   ├─ currentTask == nil: \(currentTask == nil)")
                print("[ASQ]   ├─ pendingOperation == nil (before): \(pendingOperation == nil)")
                print("[ASQ]   ├─ pendingContinuations.count (before): \(pendingContinuations.count)")
            }

            // Replace any pending operation with this new one
            let hadPendingOperation = pendingOperation != nil
            pendingOperation = operation
            pendingContinuations.append(continuation)

            if verbose {
                if hadPendingOperation {
                    print("[ASQ]   ├─ ⚠️  REPLACED previous pending operation with Operation #\(operationId)")
                } else {
                    print("[ASQ]   ├─ ✓ Set Operation #\(operationId) as pending operation")
                }
                print("[ASQ]   ├─ pendingContinuations.count (after): \(pendingContinuations.count)")
            }

            // If nothing is currently running, start processing
            if currentTask == nil {
                if verbose {
                    print("[ASQ]   └─ ▶️  No task running, calling processNext() for Operation #\(operationId)")
                }
                processNext()
            } else {
                if verbose {
                    print("[ASQ]   └─ ⏸️  Task already running, Operation #\(operationId) will wait")
                }
            }
        }
    }

    private func processNext() {
        if verbose {
            print("[ASQ] 🟢 processNext() called")
            print("[ASQ]   ├─ pendingOperation == nil: \(pendingOperation == nil)")
            print("[ASQ]   ├─ pendingContinuations.count: \(pendingContinuations.count)")
        }

        guard let operation = pendingOperation else {
            // No pending work
            if verbose {
                print("[ASQ]   ├─ ⛔ No pending operation, cleaning up")
            }
            currentTask = nil
            if verbose {
                print("[ASQ]   └─ ✓ currentTask set to nil, queue is now idle")
            }
            return
        }

        // Clear pending state and capture continuations
        pendingOperation = nil
        let continuations = pendingContinuations
        pendingContinuations = []

        if verbose {
            print("[ASQ]   ├─ ✓ Captured \(continuations.count) continuation(s) to resume")
            print("[ASQ]   ├─ ✓ Cleared pendingOperation and pendingContinuations")
            print("[ASQ]   └─ 🚀 Starting new Task to execute operation")
        }

        // Start the task
        currentTask = Task { [weak self, verbose] in
            if verbose {
                print("[ASQ]     🔄 Task execution started")
            }
            await operation()
            if verbose {
                print("[ASQ]     ✅ Task execution completed")
            }

            // Resume all waiting callers
            if verbose {
                print("[ASQ]     📤 Resuming \(continuations.count) continuation(s)")
            }
            for (index, continuation) in continuations.enumerated() {
                if verbose {
                    print("[ASQ]       ├─ Resuming continuation #\(index + 1)")
                }
                continuation.resume()
            }
            if verbose {
                print("[ASQ]     ✓ All continuations resumed")
            }

            // Process next operation if any arrived while we were running
            if verbose {
                print("[ASQ]     🔁 Checking for next operation...")
            }
            await self?.processNext()
        }
    }
}
