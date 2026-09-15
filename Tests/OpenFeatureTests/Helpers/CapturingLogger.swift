import Foundation
import OpenFeature

/// An ``OpenFeatureLogger`` that records every message it receives, for assertions in tests.
final class CapturingLogger: OpenFeatureLogger {
    enum Level {
        case debug
        case info
        case warning
        case error
    }

    struct Entry: Equatable {
        let level: Level
        let message: String
    }

    /// Identifies the logger instance so tests can check which one reached a provider.
    let name: String

    private let lock = NSLock()
    private var storage: [Entry] = []

    var entries: [Entry] {
        lock.withLock { storage }
    }

    init(name: String = "test") {
        self.name = name
    }

    func messages(at level: Level) -> [String] {
        entries.filter { $0.level == level }.map { $0.message }
    }

    func debug(_ message: @autoclosure () -> String) {
        record(.debug, message())
    }

    func info(_ message: @autoclosure () -> String) {
        record(.info, message())
    }

    func warning(_ message: @autoclosure () -> String) {
        record(.warning, message())
    }

    func error(_ message: @autoclosure () -> String) {
        record(.error, message())
    }

    private func record(_ level: Level, _ message: String) {
        lock.withLock { storage.append(Entry(level: level, message: message)) }
    }
}
