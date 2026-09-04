import Foundation
import OpenFeature
import XCTest

/// Turns raw capture groups into Swift values, failing the step rather than trapping on bad input.
enum GherkinArguments {
    static func bool(_ raw: String, file: StaticString = #filePath, line: UInt = #line) -> Bool {
        switch raw.lowercased() {
        case "true":
            return true
        case "false":
            return false
        default:
            XCTFail("Expected a boolean literal, got '\(raw)'", file: file, line: line)
            return false
        }
    }

    static func integer(_ raw: String, file: StaticString = #filePath, line: UInt = #line) -> Int64 {
        guard let value = Int64(raw) else {
            XCTFail("Expected an integer literal, got '\(raw)'", file: file, line: line)
            return 0
        }
        return value
    }

    static func double(_ raw: String, file: StaticString = #filePath, line: UInt = #line) -> Double {
        guard let value = Double(raw) else {
            XCTFail("Expected a float literal, got '\(raw)'", file: file, line: line)
            return 0
        }
        return value
    }

    /// The context step quotes its boolean, so `"false"` has to become `.boolean(false)` or the
    /// `context-aware` targeting rule never matches.
    static func boolOrString(_ raw: String) -> Value {
        switch raw.lowercased() {
        case "true":
            return .boolean(true)
        case "false":
            return .boolean(false)
        default:
            return .string(raw)
        }
    }

    /// The spec names error codes in SCREAMING_SNAKE_CASE while `ErrorCode`'s cases are camelCase.
    static func errorCode(
        _ raw: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> ErrorCode? {
        switch raw {
        case "PROVIDER_NOT_READY":
            return .providerNotReady
        case "FLAG_NOT_FOUND":
            return .flagNotFound
        case "PARSE_ERROR":
            return .parseError
        case "TYPE_MISMATCH":
            return .typeMismatch
        case "TARGETING_KEY_MISSING":
            return .targetingKeyMissing
        case "INVALID_CONTEXT":
            return .invalidContext
        case "GENERAL":
            return .general
        case "PROVIDER_FATAL":
            return .providerFatal
        default:
            XCTFail("Unknown error code '\(raw)' in the Gherkin", file: file, line: line)
            return nil
        }
    }

    /// Groups 1 to 3 are field names; 4 a boolean value, 5 a string value, 6 an integer value.
    static func assertObjectPayload(
        _ value: Value?,
        _ matches: [String],
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard let structure = value?.asStructure() else {
            XCTFail("Expected a structure, got \(String(describing: value))", file: file, line: line)
            return
        }
        XCTAssertEqual(
            structure[capture(matches, 1)],
            .boolean(bool(capture(matches, 4))),
            file: file,
            line: line)
        XCTAssertEqual(
            structure[capture(matches, 2)],
            .string(capture(matches, 5)),
            file: file,
            line: line)
        XCTAssertEqual(
            structure[capture(matches, 3)],
            .integer(integer(capture(matches, 6))),
            file: file,
            line: line)
    }
}
