import Foundation
import OpenFeature

/// An ``OpenFeatureLogger`` that records every message it receives, for assertions in tests.
final class CapturingLogger: OpenFeatureLogger {
    /// The level a message was logged at.
    enum Level {
        case debug
        case info
        case warning
        case error
    }

    /// A single recorded message.
    struct Entry: Equatable {
        let level: Level
        let message: String
    }

    /// Identifies the logger instance so tests can check which one reached a provider.
    let name: String

    private let lock = NSLock()
    private var storage: [Entry] = []

    /// All recorded messages, in the order they were logged.
    var entries: [Entry] {
        lock.withLock { storage }
    }

    /// Creates a logger identified by `name`.
    init(name: String = "test") {
        self.name = name
    }

    /// Returns the recorded messages logged at `level`, in order.
    func messages(at level: Level) -> [String] {
        entries.filter { $0.level == level }.map { $0.message }
    }

    /// Records `message` at `.debug` level.
    func debug(_ message: @autoclosure () -> String) {
        record(.debug, message())
    }

    /// Records `message` at `.info` level.
    func info(_ message: @autoclosure () -> String) {
        record(.info, message())
    }

    /// Records `message` at `.warning` level.
    func warning(_ message: @autoclosure () -> String) {
        record(.warning, message())
    }

    /// Records `message` at `.error` level.
    func error(_ message: @autoclosure () -> String) {
        record(.error, message())
    }

    /// Appends an entry under the lock.
    private func record(_ level: Level, _ message: String) {
        lock.withLock { storage.append(Entry(level: level, message: message)) }
    }
}
