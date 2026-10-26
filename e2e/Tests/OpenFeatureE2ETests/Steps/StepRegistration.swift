import CucumberSwift
import Foundation
import XCTest

// CucumberSwift's regex step API is deprecated in favour of Swift `Regex` literals, which require
// iOS 16 / macOS 13 -- above this SDK's floor. Marking these wrappers and their callers deprecated
// confines the warning.

@available(*, deprecated, message: "Wraps CucumberSwift's deprecated regex step API")
func given(
    _ pattern: String,
    line: Int = #line,
    file: StaticString = #filePath,
    _ body: @escaping ([String], Step) throws -> Void
) {
    Given(pattern, callback: body, line: line, file: file)
}

@available(*, deprecated, message: "Wraps CucumberSwift's deprecated regex step API")
func when(
    _ pattern: String,
    line: Int = #line,
    file: StaticString = #filePath,
    _ body: @escaping ([String], Step) throws -> Void
) {
    When(pattern, callback: body, line: line, file: file)
}

@available(*, deprecated, message: "Wraps CucumberSwift's deprecated regex step API")
func then(
    _ pattern: String,
    line: Int = #line,
    file: StaticString = #filePath,
    _ body: @escaping ([String], Step) throws -> Void
) {
    Then(pattern, callback: body, line: line, file: file)
}

func capture(
    _ matches: [String],
    _ index: Int,
    file: StaticString = #filePath,
    line: UInt = #line
) -> String {
    guard matches.indices.contains(index) else {
        XCTFail(
            "Step pattern produced \(matches.count) groups, wanted group \(index)",
            file: file,
            line: line)
        return ""
    }
    return matches[index]
}
