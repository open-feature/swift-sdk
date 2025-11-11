import Foundation

/// Simple serial async task queue that coalesces operations.
/// Only the currently running task and at most one pending operation are kept.
/// Intermediate operations are skipped to avoid queue buildup.
internal actor AsyncCoalescingSerialQueue {
    private var currentTask: Task<Void, Never>?
    private var pendingOperation: (() async -> Void)?
    private var pendingContinuations: [CheckedContinuation<Void, Never>] = []

    /// Runs the given operation serially. If an operation is already running,
    /// this operation replaces any previously pending operation (which gets skipped).
    /// All callers whose operations were replaced will wait for the latest operation to complete.
    func run(_ operation: @Sendable @escaping () async -> Void) async {
        await withCheckedContinuation { continuation in
            // Replace any pending operation with this new one
            pendingOperation = operation
            pendingContinuations.append(continuation)

            // If nothing is currently running, start processing
            if currentTask == nil {
                processNext()
            }
        }
    }

    private func processNext() {
        guard let operation = pendingOperation else {
            // No pending work
            currentTask = nil
            return
        }

        // Clear pending state and capture continuations
        pendingOperation = nil
        let continuations = pendingContinuations
        pendingContinuations = []

        // Start the task
        currentTask = Task { [weak self] in
            await operation()

            // Resume all waiting callers
            for continuation in continuations {
                continuation.resume()
            }

            // Process next operation if any arrived while we were running
            await self?.processNext()
        }
    }
}
