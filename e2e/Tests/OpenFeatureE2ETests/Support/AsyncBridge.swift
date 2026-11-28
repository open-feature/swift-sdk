import Foundation
import XCTest

enum AsyncBridge {
    static let defaultTimeout: TimeInterval = 10

    static func run(
        timeout: TimeInterval = AsyncBridge.defaultTimeout,
        file: StaticString = #filePath,
        line: UInt = #line,
        _ operation: @escaping @Sendable () async -> Void
    ) {
        let expectation = XCTestExpectation(description: "async work in Gherkin step")
        Task {
            await operation()
            expectation.fulfill()
        }
        if XCTWaiter().wait(for: [expectation], timeout: timeout) != .completed {
            XCTFail("Timed out after \(timeout)s waiting for async work in step", file: file, line: line)
        }
    }
}
