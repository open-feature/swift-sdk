# AsyncProviderOperationsQueue

## Overview

`AsyncProviderOperationsQueue` is a specialized serial async task queue that provides **operation-type-aware last-wins semantics** for handling OpenFeature provider operations. It ensures thread-safe, ordered execution of async operations while optimizing performance by coalescing redundant operations.

## Key Characteristics

- **Serial Execution**: Operations execute one at a time, preserving order
- **Actor-based**: Thread-safe through Swift's actor isolation
- **Smart Coalescing**: Automatically skips redundant operations based on last-wins semantics
- **Continuation Management**: All callers receive completion notification, even if their operation was skipped

## Core Concepts

### Operation Types

The queue distinguishes between two types of operations:

1. **Non-Last-Wins (`lastWins: false`)**
   - Always executes
   - Processes in strict FIFO order
   - Used for critical state changes that must not be skipped
   - Examples: `setProvider()`, `clearProvider()`

2. **Last-Wins (`lastWins: true`)**
   - May be skipped if superseded by newer last-wins operations
   - Optimizes away intermediate states
   - Used for operations where only the final state matters
   - Examples: `setEvaluationContext()`

### Batching Logic

When processing the queue, operations are grouped into "batches":

- **Batch 1**: A single non-last-wins operation
- **Batch 2**: Consecutive last-wins operations → only the last one executes

## How It Works

### Architecture

```
┌─────────────────────────────────────────┐
│   AsyncProviderOperationsQueue (Actor)  │
├─────────────────────────────────────────┤
│  - queue: [QueuedOperation]             │
│  - currentTask: Task<Void, Never>?      │
├─────────────────────────────────────────┤
│  + run(lastWins:operation:) async       │
│  - processNext()                        │
└─────────────────────────────────────────┘

QueuedOperation {
    operation: () async -> Void
    continuation: CheckedContinuation<Void, Never>
    lastWins: Bool
}
```

### Execution Flow

```
1. Caller invokes run(lastWins:operation:)
   ↓
2. Operation wrapped with continuation and enqueued
   ↓
3. If no task running → processNext()
   ↓
4. Determine batch type
   ├─ Non-last-wins: Execute single operation
   └─ Last-wins: Find consecutive last-wins ops
                 → Execute only the LAST one
                 → Skip all others
   ↓
5. Resume ALL continuations (skipped + executed)
   ↓
6. Recursively processNext() until queue empty
```

### Example Scenarios

#### Scenario 1: Non-Last-Wins Operations

```swift
// Queue: Empty, currentTask: nil

await queue.run(lastWins: false) { setProvider(A) }     // Op1
await queue.run(lastWins: false) { setProvider(B) }     // Op2
await queue.run(lastWins: false) { clearProvider() }    // Op3

// Execution order:
// 1. setProvider(A)  ✓ Executed
// 2. setProvider(B)  ✓ Executed
// 3. clearProvider() ✓ Executed
// All three operations execute in order
```

#### Scenario 2: Last-Wins Coalescing

```swift
// Queue: Empty, currentTask: nil

await queue.run(lastWins: true) { setContext(ctx1) }   // Op1
await queue.run(lastWins: true) { setContext(ctx2) }   // Op2
await queue.run(lastWins: true) { setContext(ctx3) }   // Op3

// Assume Op1 starts executing before Op2/Op3 are enqueued:
// 1. setContext(ctx1) ✓ Executed (already running)
// 2. setContext(ctx2) ✗ Skipped (superseded by ctx3)
// 3. setContext(ctx3) ✓ Executed (last in batch)

// Result: Only ctx1 and ctx3 execute
// Op2's continuation still resumes immediately when Op3 completes
```

#### Scenario 3: Mixed Operations

```swift
// Queue: Empty, currentTask: nil

await queue.run(lastWins: false) { setProvider(A) }      // Op1
await queue.run(lastWins: true)  { setContext(ctx1) }    // Op2
await queue.run(lastWins: true)  { setContext(ctx2) }    // Op3
await queue.run(lastWins: false) { setProvider(B) }      // Op4
await queue.run(lastWins: true)  { setContext(ctx3) }    // Op5

// Execution flow:
// Batch 1: [Op1] non-last-wins
//   → setProvider(A) ✓ Executed

// Batch 2: [Op2, Op3] consecutive last-wins
//   → setContext(ctx1) ✗ Skipped
//   → setContext(ctx2) ✓ Executed (last in batch)

// Batch 3: [Op4] non-last-wins
//   → setProvider(B) ✓ Executed

// Batch 4: [Op5] last-wins
//   → setContext(ctx3) ✓ Executed

// Total executions: Op1, Op2(skipped), Op3, Op4, Op5
```

## Implementation Details

### Actor Isolation

The queue is implemented as a Swift `actor`, providing:
- Automatic serialization of all property access
- Thread-safe state management
- No manual locking required

### Continuation Management

```swift
await withCheckedContinuation { continuation in
    queue.append(QueuedOperation(
        operation: operation,
        continuation: continuation,
        lastWins: lastWins
    ))
    // ...
}
```

**Key Points:**
- Each caller gets a continuation that suspends their async context
- Continuations resume when the operation completes OR is skipped
- This ensures all callers receive notification, preventing deadlocks