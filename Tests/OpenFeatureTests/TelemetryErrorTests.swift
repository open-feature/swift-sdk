import Foundation
import XCTest

@testable import OpenFeature

private typealias Fixtures = TelemetryFixtures

/// How `Telemetry.createEvaluationEvent` reports failed evaluations: `error.type` and `error.message` appear if and
/// only if the reason is `ERROR`, with the error code in lowercase snake_case (specification Appendix D).
final class TelemetryErrorTests: XCTestCase {
    func testFullyPopulatedFailedEvent() {
        let evaluation = ProviderEvaluation(
            value: false,
            reason: Reason.error.rawValue,
            errorCode: .typeMismatch,
            errorMessage: "Expected a boolean")

        let event = Fixtures.makeEvent(evaluation, context: Fixtures.makeContext(defaultValue: false))

        XCTAssertEqual(
            event.attributes,
            [
                "feature_flag.key": .string(Fixtures.flagKey),
                "feature_flag.provider.name": .string(Fixtures.providerName),
                "feature_flag.result.reason": .string("error"),
                "feature_flag.result.value": .boolean(false),
                "feature_flag.context.id": .string(Fixtures.targetingKey),
                "error.type": .string("type_mismatch"),
                "error.message": .string("Expected a boolean"),
            ])
    }

    func testErrorTypeAndMessageAreSetWhenReasonIsError() {
        let evaluation = ProviderEvaluation(
            value: "v", reason: Reason.error.rawValue, errorCode: .parseError, errorMessage: "Could not parse")

        let event = Fixtures.makeEvent(evaluation)

        XCTAssertEqual(event.attributes["error.type"], .string("parse_error"))
        XCTAssertEqual(event.attributes["error.message"], .string("Could not parse"))
    }

    func testErrorTypeDefaultsToGeneralWhenCodeIsMissing() {
        let evaluation = ProviderEvaluation(value: "v", reason: Reason.error.rawValue, errorCode: nil)

        let event = Fixtures.makeEvent(evaluation)

        XCTAssertEqual(event.attributes["error.type"], .string("general"))
        XCTAssertNil(event.attributes["error.message"])
    }

    func testErrorMessageIsOmittedWhenMissing() {
        let evaluation = ProviderEvaluation(value: "v", reason: Reason.error.rawValue, errorCode: .flagNotFound)

        let event = Fixtures.makeEvent(evaluation)

        XCTAssertEqual(event.attributes["error.type"], .string("flag_not_found"))
        XCTAssertNil(event.attributes["error.message"])
    }

    func testEmptyErrorMessageIsKeptAsIs() {
        let evaluation = ProviderEvaluation(
            value: "v", reason: Reason.error.rawValue, errorCode: .general, errorMessage: "")

        let event = Fixtures.makeEvent(evaluation)

        XCTAssertEqual(event.attributes["error.message"], .string(""))
    }

    func testErrorAttributesAreOmittedWhenReasonIsNotError() {
        let evaluation = ProviderEvaluation(
            value: "v", reason: Reason.unknown.rawValue, errorCode: .general, errorMessage: "ignored")

        let event = Fixtures.makeEvent(evaluation)

        XCTAssertNil(event.attributes["error.type"])
        XCTAssertNil(event.attributes["error.message"])
    }

    func testErrorAttributesAreOmittedWhenReasonIsMissing() {
        let evaluation = ProviderEvaluation(value: "v", reason: nil, errorCode: .general, errorMessage: "ignored")

        let event = Fixtures.makeEvent(evaluation)

        XCTAssertNil(event.attributes["error.type"])
        XCTAssertNil(event.attributes["error.message"])
    }

    func testErrorReasonIsMatchedCaseInsensitively() {
        let evaluation = ProviderEvaluation(value: "v", reason: "error", errorCode: .invalidContext)

        let event = Fixtures.makeEvent(evaluation)

        XCTAssertEqual(event.attributes["feature_flag.result.reason"], .string("error"))
        XCTAssertEqual(event.attributes["error.type"], .string("invalid_context"))
    }

    func testVariantIsStillReportedOnFailureWhenProviderSuppliesOne() {
        let evaluation = ProviderEvaluation(
            value: "v", variant: "fallback", reason: Reason.error.rawValue, errorCode: .general)

        let event = Fixtures.makeEvent(evaluation)

        XCTAssertEqual(event.attributes["feature_flag.result.variant"], .string("fallback"))
        XCTAssertEqual(event.attributes["error.type"], .string("general"))
    }

    func testEveryErrorCodeMapsToLowercaseSnakeCase() {
        let expected: [ErrorCode: String] = [
            .providerNotReady: "provider_not_ready",
            .flagNotFound: "flag_not_found",
            .parseError: "parse_error",
            .typeMismatch: "type_mismatch",
            .targetingKeyMissing: "targeting_key_missing",
            .invalidContext: "invalid_context",
            .general: "general",
            .providerFatal: "provider_fatal",
        ]

        for (code, name) in expected {
            let evaluation = ProviderEvaluation(value: "v", reason: Reason.error.rawValue, errorCode: code)
            let event = Fixtures.makeEvent(evaluation)
            XCTAssertEqual(event.attributes["error.type"], .string(name), "\(code)")
        }
    }
}
