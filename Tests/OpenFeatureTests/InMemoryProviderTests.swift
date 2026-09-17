import Foundation
import OpenFeature
import XCTest

/// Resolution of the five flag types, flag metadata, and disabled flags.
final class InMemoryProviderTests: XCTestCase {
    override func tearDown() {
        OpenFeatureAPI.shared.clearProvider()
        super.tearDown()
    }

    // MARK: - Resolution

    func testBooleanEvaluationResolvesDefaultVariant() throws {
        let result = try InMemoryTestFlags.readyProvider().getBooleanEvaluation(
            key: "boolean-flag", defaultValue: false, context: nil)

        XCTAssertEqual(result.value, true)
        XCTAssertEqual(result.variant, "on")
        XCTAssertEqual(result.reason, "STATIC")
        XCTAssertNil(result.errorCode)
    }

    func testStringEvaluationResolvesDefaultVariant() throws {
        let result = try InMemoryTestFlags.readyProvider().getStringEvaluation(
            key: "string-flag", defaultValue: "bye", context: nil)

        XCTAssertEqual(result.value, "hi")
        XCTAssertEqual(result.variant, "greeting")
        XCTAssertEqual(result.reason, "STATIC")
    }

    func testIntegerEvaluationResolvesDefaultVariant() throws {
        let result = try InMemoryTestFlags.readyProvider().getIntegerEvaluation(
            key: "integer-flag", defaultValue: 1, context: nil)

        XCTAssertEqual(result.value, 10)
        XCTAssertEqual(result.variant, "ten")
        XCTAssertEqual(result.reason, "STATIC")
    }

    func testDoubleEvaluationResolvesDefaultVariant() throws {
        let result = try InMemoryTestFlags.readyProvider().getDoubleEvaluation(
            key: "float-flag", defaultValue: 0.1, context: nil)

        XCTAssertEqual(result.value, 0.5)
        XCTAssertEqual(result.variant, "half")
        XCTAssertEqual(result.reason, "STATIC")
    }

    func testObjectEvaluationResolvesStructureVariant() throws {
        let result = try InMemoryTestFlags.readyProvider().getObjectEvaluation(
            key: "object-flag", defaultValue: .null, context: nil)

        XCTAssertEqual(result.value, InMemoryTestFlags.templateVariant)
        XCTAssertEqual(result.variant, "template")
        XCTAssertEqual(result.reason, "STATIC")
    }

    func testEvaluationCarriesFlagMetadata() throws {
        let result = try InMemoryTestFlags.readyProvider().getBooleanEvaluation(
            key: "metadata-flag", defaultValue: false, context: nil)

        XCTAssertEqual(result.flagMetadata["string"], .string("1.0.2"))
        XCTAssertEqual(result.flagMetadata["integer"], .integer(2))
        XCTAssertEqual(result.flagMetadata["boolean"], .boolean(true))
        XCTAssertEqual(result.flagMetadata["double"], .double(0.1))
    }

    func testEvaluationWithoutFlagMetadataYieldsEmptyMetadata() throws {
        let result = try InMemoryTestFlags.readyProvider().getBooleanEvaluation(
            key: "boolean-flag", defaultValue: false, context: nil)

        XCTAssertTrue(result.flagMetadata.isEmpty)
    }

    func testEvaluationThroughClientResolvesEveryType() async {
        await OpenFeatureAPI.shared.setProviderAndWait(
            provider: InMemoryProvider(flags: InMemoryTestFlags.all()))
        let client = OpenFeatureAPI.shared.getClient()

        XCTAssertEqual(client.getBooleanValue(key: "boolean-flag", defaultValue: false), true)
        XCTAssertEqual(client.getStringValue(key: "string-flag", defaultValue: "bye"), "hi")
        XCTAssertEqual(client.getIntegerValue(key: "integer-flag", defaultValue: 1), 10)
        XCTAssertEqual(client.getDoubleValue(key: "float-flag", defaultValue: 0.1), 0.5)
        XCTAssertEqual(
            client.getObjectValue(key: "object-flag", defaultValue: .null),
            InMemoryTestFlags.templateVariant)
    }

    // MARK: - Disabled flags

    func testDisabledFlagReturnsCallerDefaultWithDisabledReason() throws {
        let result = try InMemoryTestFlags.readyProvider().getBooleanEvaluation(
            key: "disabled-flag", defaultValue: false, context: nil)

        XCTAssertEqual(result.value, false)
        XCTAssertEqual(result.reason, "DISABLED")
        XCTAssertNil(result.variant)
        XCTAssertNil(result.errorCode)
    }

    func testDisabledFlagStillReturnsFlagMetadata() throws {
        let result = try InMemoryTestFlags.readyProvider().getBooleanEvaluation(
            key: "disabled-flag", defaultValue: false, context: nil)

        XCTAssertEqual(result.flagMetadata["string"], .string("1.0.2"))
    }

    // MARK: - Metadata

    func testMetadataNameAndHooks() {
        let provider = InMemoryProvider()

        XCTAssertEqual(provider.metadata.name, "InMemoryProvider")
        XCTAssertTrue(provider.hooks.isEmpty)
    }

    func testFlagsSnapshotReflectsConstructorConfiguration() {
        let provider = InMemoryProvider(flags: InMemoryTestFlags.all())

        XCTAssertEqual(Set(provider.flags.keys), Set(InMemoryTestFlags.all().keys))
    }
}
