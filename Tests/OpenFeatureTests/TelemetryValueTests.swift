import Foundation
import XCTest

@testable import OpenFeature

private typealias Fixtures = TelemetryFixtures

/// How `Telemetry.createEvaluationEvent` reports the resolved variant and value: primitives as OpenTelemetry
/// primitives, object and list values as JSON strings.
final class TelemetryValueTests: XCTestCase {
    // MARK: - Variant

    func testVariantIsTakenFromTheEvaluation() {
        let event = Fixtures.makeEvent(ProviderEvaluation(value: "v", variant: "variant-a"))

        XCTAssertEqual(event.attributes["feature_flag.result.variant"], .string("variant-a"))
    }

    func testVariantIsOmittedWhenAbsent() {
        let event = Fixtures.makeEvent(ProviderEvaluation(value: "v", variant: nil))

        XCTAssertNil(event.attributes["feature_flag.result.variant"])
    }

    func testValueIsIncludedAlongsideVariant() {
        let event = Fixtures.makeEvent(ProviderEvaluation(value: "v", variant: "variant-a"))

        XCTAssertEqual(event.attributes["feature_flag.result.value"], .string("v"))
    }

    // MARK: - Primitive flag values

    func testBooleanValue() {
        let context = Fixtures.makeContext(defaultValue: false)

        let event = Fixtures.makeEvent(ProviderEvaluation(value: true), context: context)

        XCTAssertEqual(event.attributes["feature_flag.result.value"], .boolean(true))
    }

    func testStringValue() {
        let event = Fixtures.makeEvent(ProviderEvaluation(value: "text"))

        XCTAssertEqual(event.attributes["feature_flag.result.value"], .string("text"))
    }

    func testIntegerValue() {
        let context = Fixtures.makeContext(defaultValue: Int64(0))

        let event = Fixtures.makeEvent(ProviderEvaluation(value: Int64(42)), context: context)

        XCTAssertEqual(event.attributes["feature_flag.result.value"], .integer(42))
    }

    func testDoubleValue() {
        let context = Fixtures.makeContext(defaultValue: 0.0)

        let event = Fixtures.makeEvent(ProviderEvaluation(value: 1.5), context: context)

        XCTAssertEqual(event.attributes["feature_flag.result.value"], .double(1.5))
    }

    // MARK: - Object flag values

    func testPrimitiveObjectValuesMapToNativeAttributes() {
        XCTAssertEqual(Fixtures.objectValueAttribute(.boolean(true)), .boolean(true))
        XCTAssertEqual(Fixtures.objectValueAttribute(.string("text")), .string("text"))
        XCTAssertEqual(Fixtures.objectValueAttribute(.integer(7)), .integer(7))
        XCTAssertEqual(Fixtures.objectValueAttribute(.double(2.5)), .double(2.5))
    }

    func testDateObjectValueBecomesIso8601String() {
        let date = Date(timeIntervalSince1970: 1_700_000_000.5)

        XCTAssertEqual(Fixtures.objectValueAttribute(.date(date)), .string("2023-11-14T22:13:20.500Z"))
    }

    func testNullObjectValueIsOmitted() {
        XCTAssertNil(Fixtures.objectValueAttribute(.null))
    }

    func testStructureValueBecomesJsonStringWithSortedKeys() {
        let value: Value = .structure([
            "showImages": .boolean(true),
            "title": .string("Check out these pics!"),
            "imagesPerPage": .integer(100),
        ])

        XCTAssertEqual(
            Fixtures.objectValueAttribute(value),
            .string(#"{"imagesPerPage":100,"showImages":true,"title":"Check out these pics!"}"#))
    }

    func testListValueBecomesJsonString() {
        let value: Value = .list([.string("a"), .integer(1), .boolean(true)])

        XCTAssertEqual(Fixtures.objectValueAttribute(value), .string(#"["a",1,true]"#))
    }

    func testEmptyStructureAndListBecomeJsonStrings() {
        XCTAssertEqual(Fixtures.objectValueAttribute(.structure([:])), .string("{}"))
        XCTAssertEqual(Fixtures.objectValueAttribute(.list([])), .string("[]"))
    }

    func testNestedStructureIsSerialisedRecursively() {
        let value: Value = .structure([
            "nested": .structure(["list": .list([.double(0.5), .null])]),
            "when": .date(Date(timeIntervalSince1970: 0)),
        ])

        XCTAssertEqual(
            Fixtures.objectValueAttribute(value),
            .string(#"{"nested":{"list":[0.5,null]},"when":"1970-01-01T00:00:00.000Z"}"#))
    }

    func testSlashesInJsonStringsAreNotEscaped() {
        let value: Value = .structure(["path": .string("a/b")])

        XCTAssertEqual(Fixtures.objectValueAttribute(value), .string(#"{"path":"a/b"}"#))
    }

    func testEqualStructuresProduceIdenticalJsonRegardlessOfInsertionOrder() {
        let first: Value = .structure(["b": .integer(2), "a": .integer(1), "c": .integer(3)])
        let second: Value = .structure(["c": .integer(3), "a": .integer(1), "b": .integer(2)])

        XCTAssertEqual(Fixtures.objectValueAttribute(first), Fixtures.objectValueAttribute(second))
        XCTAssertEqual(Fixtures.objectValueAttribute(first), .string(#"{"a":1,"b":2,"c":3}"#))
    }

    func testStructureThatCannotBeSerialisedIsOmitted() {
        let value: Value = .structure(["ratio": .double(.nan)])

        XCTAssertNil(Fixtures.objectValueAttribute(value))
    }

    func testListThatCannotBeSerialisedIsOmitted() {
        let value: Value = .list([.double(.infinity)])

        XCTAssertNil(Fixtures.objectValueAttribute(value))
    }

    // MARK: - Edge cases

    func testEmptyVariantIsKeptAsIs() {
        let event = Fixtures.makeEvent(ProviderEvaluation(value: "v", variant: ""))

        XCTAssertEqual(event.attributes["feature_flag.result.variant"], .string(""))
    }

    func testIntegerExtremesInStructuresKeepPrecision() {
        let value: Value = .structure(["max": .integer(.max), "min": .integer(.min)])

        XCTAssertEqual(
            Fixtures.objectValueAttribute(value),
            .string(#"{"max":9223372036854775807,"min":-9223372036854775808}"#))
    }

    func testNonAsciiStringsInStructuresAreNotEscaped() {
        let value: Value = .structure(["greeting": .string("héllo wörld ✓")])

        XCTAssertEqual(Fixtures.objectValueAttribute(value), .string(#"{"greeting":"héllo wörld ✓"}"#))
    }

    func testConcurrentEventCreationProducesConsistentResults() {
        let date = Date(timeIntervalSince1970: 1_700_000_000.5)
        let structure: Value = .structure(["n": .integer(1), "when": .date(date)])
        let expectedStructure: TelemetryAttributeValue = .string(#"{"n":1,"when":"2023-11-14T22:13:20.500Z"}"#)
        let expectedDate: TelemetryAttributeValue = .string("2023-11-14T22:13:20.500Z")
        let lock = NSLock()
        var mismatches = 0

        DispatchQueue.concurrentPerform(iterations: 200) { _ in
            let structureAttribute = Fixtures.objectValueAttribute(structure)
            let dateAttribute = Fixtures.objectValueAttribute(.date(date))
            if structureAttribute != expectedStructure || dateAttribute != expectedDate {
                lock.withLock { mismatches += 1 }
            }
        }

        XCTAssertEqual(mismatches, 0)
    }

    // MARK: - Unsupported flag value types

    func testValueOfTypeTheSdkDoesNotEvaluateIsOmitted() {
        struct Custom: Equatable {}
        let context = Fixtures.makeContext(defaultValue: Custom())

        let event = Fixtures.makeEvent(ProviderEvaluation(value: Custom()), context: context)

        XCTAssertNil(event.attributes["feature_flag.result.value"])
        XCTAssertEqual(event.attributes["feature_flag.key"], .string(Fixtures.flagKey))
    }
}
