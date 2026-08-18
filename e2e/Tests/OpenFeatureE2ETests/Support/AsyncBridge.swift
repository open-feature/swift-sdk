import Foundation
import XCTest

/// Runs `async` SDK calls from CucumberSwift's synchronous step closures. `XCTWaiter` rather than
/// a `DispatchSemaphore`, which would deadlock the moment a provider or hook hopped to the main queue.
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
