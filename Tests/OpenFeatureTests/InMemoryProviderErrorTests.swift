import Foundation
import OpenFeature
import XCTest

/// Error paths of `InMemoryProvider`, and how the client surfaces them.
final class InMemoryProviderErrorTests: XCTestCase {
    override func tearDown() {
        OpenFeatureAPI.shared.clearProvider()
        super.tearDown()
    }

    private func assertThrows(
        _ expected: ErrorCode,
        _ expression: () throws -> Void,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertThrowsError(try expression(), file: file, line: line) { error in
            XCTAssertEqual((error as? OpenFeatureError)?.errorCode(), expected, file: file, line: line)
        }
    }

    // MARK: - Provider errors

    func testUnknownFlagKeyThrowsFlagNotFound() {
        let provider = InMemoryTestFlags.readyProvider()

        assertThrows(.flagNotFound) {
            _ = try provider.getStringEvaluation(key: "missing-flag", defaultValue: "uh-oh", context: nil)
        }
    }

    func testStringFlagEvaluatedAsIntegerThrowsTypeMismatch() {
        let provider = InMemoryTestFlags.readyProvider()

        assertThrows(.typeMismatch) {
            _ = try provider.getIntegerEvaluation(key: "string-flag", defaultValue: 13, context: nil)
        }
    }

    func testIntegerVariantEvaluatedAsDoubleThrowsTypeMismatch() {
        let provider = InMemoryTestFlags.readyProvider()

        assertThrows(.typeMismatch) {
            _ = try provider.getDoubleEvaluation(key: "integer-flag", defaultValue: 0.1, context: nil)
        }
    }

    func testDoubleVariantEvaluatedAsIntegerThrowsTypeMismatch() {
        let provider = InMemoryTestFlags.readyProvider()

        assertThrows(.typeMismatch) {
            _ = try provider.getIntegerEvaluation(key: "float-flag", defaultValue: 1, context: nil)
        }
    }

    func testScalarFlagEvaluatedAsObjectThrowsTypeMismatch() {
        let provider = InMemoryTestFlags.readyProvider()

        assertThrows(.typeMismatch) {
            _ = try provider.getObjectEvaluation(key: "boolean-flag", defaultValue: .null, context: nil)
        }
    }

    func testEvaluationBeforeInitializeThrowsProviderNotReady() {
        let provider = InMemoryProvider(flags: InMemoryTestFlags.all())
        XCTAssertEqual(provider.status, .notReady)

        assertThrows(.providerNotReady) {
            _ = try provider.getBooleanEvaluation(key: "boolean-flag", defaultValue: false, context: nil)
        }
    }

    func testDefaultVariantMissingFromVariantsThrowsGeneralError() {
        let provider = InMemoryTestFlags.readyProvider()

        assertThrows(.general) {
            _ = try provider.getBooleanEvaluation(
                key: "missing-variant-flag", defaultValue: false, context: nil)
        }
    }

    func testContextEvaluatorReturningUnknownVariantThrowsGeneralError() {
        let evaluator: InMemoryFlag.ContextEvaluator = { _, _ in "nope" }
        let flag = InMemoryFlag(
            variants: ["on": .boolean(true)], defaultVariant: "on", contextEvaluator: evaluator)
        let provider = InMemoryTestFlags.readyProvider(flags: ["bad-targeting": flag])

        assertThrows(.general) {
            _ = try provider.getBooleanEvaluation(key: "bad-targeting", defaultValue: false, context: nil)
        }
    }

    // MARK: - Client mapping

    func testClientMapsFlagNotFoundToDetailsWithFallbackValue() async {
        await OpenFeatureAPI.shared.setProviderAndWait(
            provider: InMemoryProvider(flags: InMemoryTestFlags.all()))

        let details = OpenFeatureAPI.shared.getClient().getStringDetails(
            key: "missing-flag", defaultValue: "uh-oh")

        XCTAssertEqual(details.value, "uh-oh")
        XCTAssertEqual(details.reason, "ERROR")
        XCTAssertEqual(details.errorCode, .flagNotFound)
        XCTAssertNil(details.variant)
    }

    func testClientMapsTypeMismatchToDetailsWithFallbackValue() async {
        await OpenFeatureAPI.shared.setProviderAndWait(
            provider: InMemoryProvider(flags: InMemoryTestFlags.all()))

        let details = OpenFeatureAPI.shared.getClient().getIntegerDetails(
            key: "string-flag", defaultValue: 13)

        XCTAssertEqual(details.value, 13)
        XCTAssertEqual(details.reason, "ERROR")
        XCTAssertEqual(details.errorCode, .typeMismatch)
    }
}
