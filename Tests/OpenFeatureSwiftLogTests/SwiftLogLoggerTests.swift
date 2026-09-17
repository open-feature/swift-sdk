import Foundation
import Logging
import OpenFeature
import OpenFeatureSwiftLog
import XCTest

final class SwiftLogLoggerTests: XCTestCase {
    private func makeLogger() -> (SwiftLogLogger, CapturingLogHandler) {
        let handler = CapturingLogHandler()
        let logger = Logger(label: "test.swiftlog") { _ in handler }
        return (SwiftLogLogger(logger), handler)
    }

    func testForwardsEachLevelToSwiftLog() {
        let (logger, handler) = makeLogger()

        logger.debug("debug message")
        logger.info("info message")
        logger.warning("warning message")
        logger.error("error message")

        XCTAssertEqual(
            handler.entries,
            [
                CapturingLogHandler.Entry(level: .debug, message: "debug message"),
                CapturingLogHandler.Entry(level: .info, message: "info message"),
                CapturingLogHandler.Entry(level: .warning, message: "warning message"),
                CapturingLogHandler.Entry(level: .error, message: "error message"),
            ]
        )
    }

    func testMessageIsNotEvaluatedBelowLogLevel() {
        let (logger, handler) = makeLogger()
        handler.logLevel = .error
        var evaluated = false
        func expensiveMessage() -> String {
            evaluated = true
            return "expensive"
        }

        logger.debug(expensiveMessage())

        XCTAssertFalse(evaluated, "Message autoclosure must not run when swift-log filters the level")
        XCTAssertTrue(handler.entries.isEmpty)
    }

    func testLabelInitializerWrapsSwiftLogLogger() {
        let logger = SwiftLogLogger(label: "com.example.openfeature")

        XCTAssertEqual(logger.logger.label, "com.example.openfeature")
    }

    func testCanBeInstalledOnOpenFeatureAPI() {
        let api = OpenFeatureAPI()
        let (logger, _) = makeLogger()

        api.setLogger(logger)

        XCTAssertEqual((api.getLogger() as? SwiftLogLogger)?.logger.label, "test.swiftlog")
    }
}

/// A swift-log handler that records what reaches it.
final class CapturingLogHandler: LogHandler {
    struct Entry: Equatable {
        let level: Logger.Level
        let message: String
    }

    private let lock = NSLock()
    private var storage: [Entry] = []

    var entries: [Entry] {
        lock.withLock { storage }
    }

    var metadata: Logger.Metadata = [:]
    var logLevel: Logger.Level = .trace

    subscript(metadataKey key: String) -> Logger.Metadata.Value? {
        get { metadata[key] }
        set { metadata[key] = newValue }
    }

    // swiftlint:disable:next function_parameter_count
    func log(
        level: Logger.Level,
        message: Logger.Message,
        metadata: Logger.Metadata?,
        source: String,
        file: String,
        function: String,
        line: UInt
    ) {
        lock.withLock { storage.append(Entry(level: level, message: message.description)) }
    }
}
