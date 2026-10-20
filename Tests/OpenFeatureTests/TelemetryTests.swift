import Foundation
import XCTest

@testable import OpenFeature

private typealias Fixtures = TelemetryFixtures

/// `Telemetry.createEvaluationEvent` against hand-built contexts and details: the event shape and the attributes
/// drawn from the flag key, provider, reason, evaluation context and flag metadata (specification Appendix D).
/// Values are covered by `TelemetryValueTests`, failures by `TelemetryErrorTests`.
final class TelemetryTests: XCTestCase {
    // MARK: - Event shape

    func testEventNameIsFeatureFlagEvaluation() {
        let event = Fixtures.makeEvent(ProviderEvaluation(value: "resolved"))

        XCTAssertEqual(event.name, "feature_flag.evaluation")
        XCTAssertEqual(event.name, Telemetry.evaluationEventName)
    }

    func testAttributeNamesMatchTheSpecification() {
        XCTAssertEqual(Telemetry.Attribute.flagKey, "feature_flag.key")
        XCTAssertEqual(Telemetry.Attribute.providerName, "feature_flag.provider.name")
        XCTAssertEqual(Telemetry.Attribute.reason, "feature_flag.result.reason")
        XCTAssertEqual(Telemetry.Attribute.variant, "feature_flag.result.variant")
        XCTAssertEqual(Telemetry.Attribute.value, "feature_flag.result.value")
        XCTAssertEqual(Telemetry.Attribute.contextId, "feature_flag.context.id")
        XCTAssertEqual(Telemetry.Attribute.flagSetId, "feature_flag.set.id")
        XCTAssertEqual(Telemetry.Attribute.version, "feature_flag.version")
        XCTAssertEqual(Telemetry.Attribute.errorType, "error.type")
        XCTAssertEqual(Telemetry.Attribute.errorMessage, "error.message")
        XCTAssertEqual(Telemetry.FlagMetadataKey.contextId, "contextId")
        XCTAssertEqual(Telemetry.FlagMetadataKey.flagSetId, "flagSetId")
        XCTAssertEqual(Telemetry.FlagMetadataKey.version, "version")
    }

    func testMinimalEventContainsOnlyRequiredAttributes() {
        let context = Fixtures.makeContext(defaultValue: "", targetingKey: nil, providerMetadata: nil)

        let event = Fixtures.makeEvent(ProviderEvaluation(value: "resolved"), context: context)

        XCTAssertEqual(
            event.attributes,
            [
                "feature_flag.key": .string(Fixtures.flagKey),
                "feature_flag.result.reason": .string("unknown"),
                "feature_flag.result.value": .string("resolved"),
            ])
    }

    func testFullyPopulatedSuccessfulEvent() {
        let evaluation = ProviderEvaluation(
            value: true,
            flagMetadata: [
                "contextId": .string("ctx-1"),
                "flagSetId": .string("set-1"),
                "version": .string("v1"),
            ],
            variant: "on",
            reason: Reason.targetingMatch.rawValue)

        let event = Fixtures.makeEvent(evaluation, context: Fixtures.makeContext(defaultValue: false))

        XCTAssertEqual(
            event.attributes,
            [
                "feature_flag.key": .string(Fixtures.flagKey),
                "feature_flag.provider.name": .string(Fixtures.providerName),
                "feature_flag.result.reason": .string("targeting_match"),
                "feature_flag.result.variant": .string("on"),
                "feature_flag.result.value": .boolean(true),
                "feature_flag.context.id": .string("ctx-1"),
                "feature_flag.set.id": .string("set-1"),
                "feature_flag.version": .string("v1"),
            ])
    }

    func testEventsAreEquatable() {
        let first = Fixtures.makeEvent(ProviderEvaluation(value: "a", variant: "x"))
        let same = Fixtures.makeEvent(ProviderEvaluation(value: "a", variant: "x"))
        let different = Fixtures.makeEvent(ProviderEvaluation(value: "a", variant: "y"))

        XCTAssertEqual(first, same)
        XCTAssertNotEqual(first, different)
    }

    // MARK: - Flag key and provider

    func testFlagKeyIsTakenFromTheHookContext() {
        let context = Fixtures.makeContext(flagKey: "other-key", defaultValue: "")

        let event = Fixtures.makeEvent(ProviderEvaluation(value: "v"), context: context)

        XCTAssertEqual(event.attributes["feature_flag.key"], .string("other-key"))
    }

    func testProviderNameIsTakenFromProviderMetadata() {
        let event = Fixtures.makeEvent(ProviderEvaluation(value: "v"))

        XCTAssertEqual(event.attributes["feature_flag.provider.name"], .string(Fixtures.providerName))
    }

    func testProviderNameIsOmittedWhenMetadataHasNoName() {
        let metadata = Fixtures.ProviderMetadataStub(name: nil)
        let context = Fixtures.makeContext(defaultValue: "", providerMetadata: metadata)

        let event = Fixtures.makeEvent(ProviderEvaluation(value: "v"), context: context)

        XCTAssertNil(event.attributes["feature_flag.provider.name"])
    }

    func testProviderNameIsOmittedWhenThereIsNoProviderMetadata() {
        let context = Fixtures.makeContext(defaultValue: "", providerMetadata: nil)

        let event = Fixtures.makeEvent(ProviderEvaluation(value: "v"), context: context)

        XCTAssertNil(event.attributes["feature_flag.provider.name"])
    }

    func testEmptyProviderNameIsKeptAsIs() {
        let metadata = Fixtures.ProviderMetadataStub(name: "")
        let context = Fixtures.makeContext(defaultValue: "", providerMetadata: metadata)

        let event = Fixtures.makeEvent(ProviderEvaluation(value: "v"), context: context)

        XCTAssertEqual(event.attributes["feature_flag.provider.name"], .string(""))
    }

    // MARK: - Reason

    func testReasonIsLowercased() {
        let event = Fixtures.makeEvent(ProviderEvaluation(value: "v", reason: Reason.targetingMatch.rawValue))

        XCTAssertEqual(event.attributes["feature_flag.result.reason"], .string("targeting_match"))
    }

    func testReasonDefaultsToUnknown() {
        let event = Fixtures.makeEvent(ProviderEvaluation(value: "v", reason: nil))

        XCTAssertEqual(event.attributes["feature_flag.result.reason"], .string("unknown"))
    }

    func testProviderSpecificReasonIsPassedThroughLowercased() {
        let custom = Fixtures.makeEvent(ProviderEvaluation(value: "v", reason: "CUSTOM_RULE"))
        let mixedCase = Fixtures.makeEvent(ProviderEvaluation(value: "v", reason: "Targeting_Match"))

        XCTAssertEqual(custom.attributes["feature_flag.result.reason"], .string("custom_rule"))
        XCTAssertEqual(mixedCase.attributes["feature_flag.result.reason"], .string("targeting_match"))
        XCTAssertNil(custom.attributes["error.type"])
    }

    func testEveryStandardReasonIsLowercasedSnakeCase() {
        let expected: [Reason: String] = [
            .staticReason: "static",
            .defaultReason: "default",
            .targetingMatch: "targeting_match",
            .split: "split",
            .cached: "cached",
            .disabled: "disabled",
            .unknown: "unknown",
            .stale: "stale",
            .error: "error",
        ]

        for (reason, name) in expected {
            let event = Fixtures.makeEvent(ProviderEvaluation(value: "v", reason: reason.rawValue))
            XCTAssertEqual(event.attributes["feature_flag.result.reason"], .string(name), "\(reason)")
        }
    }

    // MARK: - Context id

    func testContextIdIsTakenFromFlagMetadata() {
        let event = Fixtures.makeEvent(ProviderEvaluation(value: "v", flagMetadata: ["contextId": .string("ctx-1")]))

        XCTAssertEqual(event.attributes["feature_flag.context.id"], .string("ctx-1"))
    }

    func testContextIdFallsBackToTargetingKey() {
        let event = Fixtures.makeEvent(ProviderEvaluation(value: "v"))

        XCTAssertEqual(event.attributes["feature_flag.context.id"], .string(Fixtures.targetingKey))
    }

    func testContextIdFromMetadataWinsOverTargetingKey() {
        let event = Fixtures.makeEvent(ProviderEvaluation(value: "v", flagMetadata: ["contextId": .string("ctx-1")]))

        XCTAssertEqual(event.attributes["feature_flag.context.id"], .string("ctx-1"))
        XCTAssertNotEqual(event.attributes["feature_flag.context.id"], .string(Fixtures.targetingKey))
    }

    func testContextIdIsOmittedWhenThereIsNoEvaluationContext() {
        let context = Fixtures.makeContext(defaultValue: "", targetingKey: nil)

        let event = Fixtures.makeEvent(ProviderEvaluation(value: "v"), context: context)

        XCTAssertNil(event.attributes["feature_flag.context.id"])
    }

    func testContextIdIsOmittedWhenTargetingKeyIsEmpty() {
        let context = Fixtures.makeContext(defaultValue: "", targetingKey: "")

        let event = Fixtures.makeEvent(ProviderEvaluation(value: "v"), context: context)

        XCTAssertNil(event.attributes["feature_flag.context.id"])
    }

    func testEmptyContextIdMetadataDoesNotFallBackToTargetingKey() {
        let event = Fixtures.makeEvent(ProviderEvaluation(value: "v", flagMetadata: ["contextId": .string("")]))

        XCTAssertNil(event.attributes["feature_flag.context.id"])
    }

    func testNonStringContextIdMetadataIsIgnored() {
        let event = Fixtures.makeEvent(ProviderEvaluation(value: "v", flagMetadata: ["contextId": .integer(42)]))

        XCTAssertEqual(event.attributes["feature_flag.context.id"], .string(Fixtures.targetingKey))
    }

    // MARK: - Flag set id and version

    func testFlagSetIdIsTakenFromFlagMetadata() {
        let event = Fixtures.makeEvent(ProviderEvaluation(value: "v", flagMetadata: ["flagSetId": .string("proj-1")]))

        XCTAssertEqual(event.attributes["feature_flag.set.id"], .string("proj-1"))
    }

    func testFlagSetIdIsOmittedWhenAbsent() {
        let event = Fixtures.makeEvent(ProviderEvaluation(value: "v"))

        XCTAssertNil(event.attributes["feature_flag.set.id"])
    }

    func testNonStringFlagSetIdMetadataIsIgnored() {
        let event = Fixtures.makeEvent(ProviderEvaluation(value: "v", flagMetadata: ["flagSetId": .boolean(true)]))

        XCTAssertNil(event.attributes["feature_flag.set.id"])
    }

    func testVersionIsTakenFromFlagMetadata() {
        let metadata: FlagMetadata = ["version": .string("2024-01-01")]

        let event = Fixtures.makeEvent(ProviderEvaluation(value: "v", flagMetadata: metadata))

        XCTAssertEqual(event.attributes["feature_flag.version"], .string("2024-01-01"))
    }

    func testVersionIsOmittedWhenAbsent() {
        let event = Fixtures.makeEvent(ProviderEvaluation(value: "v"))

        XCTAssertNil(event.attributes["feature_flag.version"])
    }

    func testNonStringVersionMetadataIsIgnored() {
        let event = Fixtures.makeEvent(ProviderEvaluation(value: "v", flagMetadata: ["version": .double(2.0)]))

        XCTAssertNil(event.attributes["feature_flag.version"])
    }

    func testUnrelatedFlagMetadataIsNotExported() {
        let event = Fixtures.makeEvent(ProviderEvaluation(value: "v", flagMetadata: ["experiment": .string("exp-1")]))

        XCTAssertNil(event.attributes["experiment"])
        XCTAssertNil(event.attributes["feature_flag.experiment"])
    }
}
