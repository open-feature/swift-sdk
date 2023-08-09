import Foundation
import XCTest

@testable import OpenFeature

final class ProviderSpecTests: XCTestCase {
    func testFlagValueSet() throws {
        let provider = NoOpProvider()

        let boolResult = try provider.getBooleanEvaluation(key: "key", defaultValue: false, context: MutableContext())
        XCTAssertNotNil(boolResult.value)

        let stringResult = try provider.getStringEvaluation(key: "key", defaultValue: "test", context: MutableContext())
        XCTAssertNotNil(stringResult.value)

        let intResult = try provider.getIntegerEvaluation(key: "key", defaultValue: 4, context: MutableContext())
        XCTAssertNotNil(intResult.value)

        let doubleResult = try provider.getDoubleEvaluation(key: "key", defaultValue: 0.4, context: MutableContext())
        XCTAssertNotNil(doubleResult.value)

        let objectResult = try provider.getObjectEvaluation(key: "key", defaultValue: .null, context: MutableContext())
        XCTAssertNotNil(objectResult.value)
    }

    func testHasReason() throws {
        let provider = NoOpProvider()

        let boolResult = try provider.getBooleanEvaluation(key: "key", defaultValue: false, context: MutableContext())
        XCTAssertEqual(boolResult.reason, Reason.defaultReason.rawValue)
    }

    func testNoErrorCodeByDefault() throws {
        let provider = NoOpProvider()

        let boolResult = try provider.getBooleanEvaluation(key: "key", defaultValue: false, context: MutableContext())
        XCTAssertNil(boolResult.errorCode)
    }

    func testVariantIsSet() throws {
        let provider = NoOpProvider()

        let boolResult = try provider.getBooleanEvaluation(key: "key", defaultValue: false, context: MutableContext())
        XCTAssertNotNil(boolResult.variant)

        let stringResult = try provider.getStringEvaluation(key: "key", defaultValue: "test", context: MutableContext())
        XCTAssertNotNil(stringResult.variant)

        let intResult = try provider.getIntegerEvaluation(key: "key", defaultValue: 4, context: MutableContext())
        XCTAssertNotNil(intResult.variant)

        let doubleResult = try provider.getDoubleEvaluation(key: "key", defaultValue: 0.4, context: MutableContext())
        XCTAssertNotNil(doubleResult.variant)

        let objectResult = try provider.getObjectEvaluation(key: "key", defaultValue: .null, context: MutableContext())
        XCTAssertNotNil(objectResult.variant)
    }
}
