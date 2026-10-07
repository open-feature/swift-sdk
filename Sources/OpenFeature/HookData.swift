import Foundation

/// Mutable storage scoped to one ``Hook`` and one flag evaluation.
///
/// The SDK creates a fresh instance for every hook on every evaluation, before that hook's `before` stage runs,
/// and hands the same instance to its `after`, `error` and `finally` stages. It is never shared between hooks and
/// never reused across evaluations, so a hook can carry state such as a timer, a span or a correlation ID from
/// one stage to the next without touching the evaluation context.
///
/// Keys are strings and values can be of any type. Nothing stored here is serialised or passed to the provider.
/// Access is lock-protected, so a hook may also read or write the store from another queue.
public final class HookData {
    private let lock = NSLock()
    private var storage: [String: Any] = [:]

    public init() {}

    /// Reads or writes the value stored under `key`. Assigning `nil` removes the key.
    public subscript(key: String) -> Any? {
        get { lock.withLock { storage[key] } }
        set { lock.withLock { storage[key] = newValue } }
    }

    /// The keys currently stored.
    public var keys: Set<String> {
        lock.withLock { Set(storage.keys) }
    }

    /// `true` when nothing is stored.
    public var isEmpty: Bool {
        lock.withLock { storage.isEmpty }
    }
}
