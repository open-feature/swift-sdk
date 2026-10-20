import Foundation
import XCTest

@testable import OpenFeature

/// `Telemetry.createEvaluationEvent` used the way it is meant to be: from a hook's `finally` stage, on evaluations
/// that went through the client and a real provider.
final class TelemetryHookSpecTests: XCTestCase {
    override func setUp() async throws {
        try await super.setUp()
        await OpenFeatureAPI.shared.clearProviderAndWait()
        // The API keeps the evaluation context across providers; start every test without a targeting key.
        await OpenFeatureAPI.shared.setEvaluationContextAndWait(evaluationContext: ImmutableContext())
        OpenFeatureAPI.shared.clearHooks()
    }

    func testSuccessfulEvaluationProducesCompleteEvent() async {
        let provider = InMemoryProvider(flags: InMemoryTestFlags.all())
        await OpenFeatureAPI.shared.setProviderAndWait(
            provider: provider,
            initialContext: ImmutableContext(targetingKey: "user-1"))
        let client = OpenFeatureAPI.shared.getClient()
        let hook = TelemetryCapturingHook()

        let value = client.getValue(
            key: "boolean-flag", defaultValue: false, options: FlagEvaluationOptions(hooks: [hook]))

        XCTAssertTrue(value)
        XCTAssertEqual(hook.events.count, 1)
        XCTAssertEqual(
            hook.events.first,
            EvaluationEvent(
                name: "feature_flag.evaluation",
                attributes: [
                    "feature_flag.key": .string("boolean-flag"),
                    "feature_flag.provider.name": .string(InMemoryProvider.name),
                    "feature_flag.result.reason": .string("static"),
                    "feature_flag.result.variant": .string("on"),
                    "feature_flag.result.value": .boolean(true),
                    "feature_flag.context.id": .string("user-1"),
                ]))
    }

    func testTelemetryFlagMetadataIsMappedToAttributes() async {
        let flag = InMemoryFlag(
            variants: ["on": .boolean(true)],
            defaultVariant: "on",
            flagMetadata: [
                "contextId": .string("ctx-42"),
                "flagSetId": .string("proj-1"),
                "version": .string("2024-01-01"),
            ])
        await OpenFeatureAPI.shared.setProviderAndWait(
            provider: InMemoryProvider(flags: ["telemetry-flag": flag]),
            initialContext: ImmutableContext(targetingKey: "user-1"))
        let client = OpenFeatureAPI.shared.getClient()
        let hook = TelemetryCapturingHook()

        _ = client.getValue(key: "telemetry-flag", defaultValue: false, options: FlagEvaluationOptions(hooks: [hook]))

        let attributes = hook.events.first?.attributes
        XCTAssertEqual(
            attributes?["feature_flag.context.id"], .string("ctx-42"), "metadata wins over the targeting key")
        XCTAssertEqual(attributes?["feature_flag.set.id"], .string("proj-1"))
        XCTAssertEqual(attributes?["feature_flag.version"], .string("2024-01-01"))
    }

    func testObjectValueIsCarriedAsJsonString() async {
        await OpenFeatureAPI.shared.setProviderAndWait(provider: InMemoryProvider(flags: InMemoryTestFlags.all()))
        let client = OpenFeatureAPI.shared.getClient()
        let hook = TelemetryCapturingHook()

        _ = client.getValue(key: "object-flag", defaultValue: Value.null, options: FlagEvaluationOptions(hooks: [hook]))

        XCTAssertEqual(
            hook.events.first?.attributes["feature_flag.result.value"],
            .string(#"{"imagesPerPage":100,"showImages":true,"title":"Check out these pics!"}"#))
        XCTAssertEqual(hook.events.first?.attributes["feature_flag.result.variant"], .string("template"))
    }

    func testFailedEvaluationProducesErrorEvent() {
        let provider = AlwaysBrokenProvider()
        let eventState = installProviderAndWaitForError(provider)
        let client = OpenFeatureAPI.shared.getClient()
        let hook = TelemetryCapturingHook()

        _ = client.getValue(key: "missing", defaultValue: true, options: FlagEvaluationOptions(hooks: [hook]))

        XCTAssertEqual(hook.events.count, 1)
        XCTAssertEqual(
            hook.events.first,
            EvaluationEvent(
                name: "feature_flag.evaluation",
                attributes: [
                    "feature_flag.key": .string("missing"),
                    "feature_flag.provider.name": .string("test"),
                    "feature_flag.result.reason": .string("error"),
                    "feature_flag.result.value": .boolean(true),
                    "error.type": .string("flag_not_found"),
                    "error.message": .string("\(OpenFeatureError.flagNotFoundError(key: "missing"))"),
                ]))
        XCTAssertNotNil(eventState)
    }

    func testEvaluationWithoutProviderProducesProviderNotReadyEvent() async {
        await OpenFeatureAPI.shared.clearProviderAndWait()
        let client = OpenFeatureAPI.shared.getClient()
        let hook = TelemetryCapturingHook()

        _ = client.getValue(key: "key", defaultValue: "fallback", options: FlagEvaluationOptions(hooks: [hook]))

        let attributes = hook.events.first?.attributes
        XCTAssertEqual(attributes?["feature_flag.result.reason"], .string("error"))
        XCTAssertEqual(attributes?["error.type"], .string("provider_not_ready"))
        XCTAssertEqual(attributes?["feature_flag.result.value"], .string("fallback"))
        XCTAssertNil(attributes?["feature_flag.provider.name"])
        XCTAssertNil(attributes?["feature_flag.result.variant"])
        XCTAssertNil(attributes?["feature_flag.context.id"])
    }

    func testEveryFlagValueTypeProducesAnEvent() async {
        await OpenFeatureAPI.shared.setProviderAndWait(provider: NoOpProvider())
        let client = OpenFeatureAPI.shared.getClient()
        let hook = TelemetryCapturingHook()
        client.addHooks(hook)

        _ = client.getValue(key: "bool", defaultValue: true)
        _ = client.getValue(key: "string", defaultValue: "text")
        _ = client.getValue(key: "int", defaultValue: Int64(7))
        _ = client.getValue(key: "double", defaultValue: 2.5)
        _ = client.getValue(key: "object", defaultValue: Value.structure(["enabled": .boolean(false)]))

        XCTAssertEqual(
            hook.events.map { $0.attributes["feature_flag.key"] },
            [
                .string("bool"), .string("string"), .string("int"), .string("double"), .string("object"),
            ])
        XCTAssertEqual(
            hook.events.map { $0.attributes["feature_flag.result.value"] },
            [
                .boolean(true), .string("text"), .integer(7), .double(2.5), .string(#"{"enabled":false}"#),
            ])
        XCTAssertTrue(hook.events.allSatisfy { $0.attributes["feature_flag.result.reason"] == .string("default") })
        XCTAssertTrue(hook.events.allSatisfy { $0.attributes["feature_flag.result.variant"] != nil })
    }

    func testEventIsCreatedOncePerEvaluation() async {
        await OpenFeatureAPI.shared.setProviderAndWait(provider: NoOpProvider())
        let client = OpenFeatureAPI.shared.getClient()
        let hook = TelemetryCapturingHook()
        client.addHooks(hook)

        _ = client.getValue(key: "first", defaultValue: false)
        _ = client.getValue(key: "second", defaultValue: false)
        _ = client.getValue(key: "third", defaultValue: false)

        XCTAssertEqual(hook.events.count, 3)
        XCTAssertEqual(hook.events.map(\.name), Array(repeating: "feature_flag.evaluation", count: 3))
    }
}
