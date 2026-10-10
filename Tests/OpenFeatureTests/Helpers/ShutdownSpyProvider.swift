import Combine
import Foundation

@testable import OpenFeature

/// A `NoOpProvider` that counts `shutdown` calls, reports its lifecycle calls in order, and can hold its shutdown
/// open until the test releases it.
final class ShutdownSpyProvider: NoOpProvider {
    private let lock = NSLock()
    private var _shutdownCalls = 0
    private var pendingShutdowns: [Future<Void, Never>.Promise] = []
    private let onLifecycle: ((String) -> Void)?
    private let holdShutdown: Bool

    /// - Parameters:
    ///   - name: Reported as the provider's metadata name and in lifecycle entries (`"shutdown:<name>"`).
    ///   - holdShutdown: When `true`, the `Future` returned by `shutdown` resolves only after `completeShutdown()`.
    ///   - onLifecycle: Receives `"initialize:<name>"` and `"shutdown:<name>"` as the SDK calls them.
    init(name: String = "spy", holdShutdown: Bool = false, onLifecycle: ((String) -> Void)? = nil) {
        self.holdShutdown = holdShutdown
        self.onLifecycle = onLifecycle
        super.init()
        self.metadata = NoOpMetadata(name: name)
    }

    /// How many times the SDK has called `shutdown`.
    var shutdownCalls: Int {
        lock.withLock { _shutdownCalls }
    }

    private var name: String {
        metadata.name ?? ""
    }

    override func initialize(initialContext: EvaluationContext?) -> Future<Void, Never> {
        onLifecycle?("initialize:\(name)")
        return super.initialize(initialContext: initialContext)
    }

    override func shutdown() -> Future<Void, Never> {
        lock.withLock { _shutdownCalls += 1 }
        onLifecycle?("shutdown:\(name)")
        let immediate = super.shutdown()
        guard holdShutdown else {
            return immediate
        }
        return Future { promise in
            self.lock.withLock { self.pendingShutdowns.append(promise) }
        }
    }

    /// Resolves every shutdown `Future` that is being held open.
    func completeShutdown() {
        let promises = lock.withLock { () -> [Future<Void, Never>.Promise] in
            let pending = pendingShutdowns
            pendingShutdowns.removeAll()
            return pending
        }
        promises.forEach { $0(.success(())) }
    }
}
