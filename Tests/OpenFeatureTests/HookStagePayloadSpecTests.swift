import Foundation
import XCTest

@testable import OpenFeature

/// What each hook stage receives alongside its hook data: the resolved details, the thrown error, the hints and the
/// per-hook context fields; plus the lifetime guarantee that the SDK lets go of hook data once an evaluation ends.
final class HookStagePayloadSpecTests: XCTestCase {
    override func setUp() async throws {
        try await super.setUp()
        await OpenFeatureAPI.shared.clearProviderAndWait()
        OpenFeatureAPI.shared.clearHooks()
    }

    // MARK: - Details

    func testAfterAndFinallyReceiveTheResolvedDetails() async {
        await OpenFeatureAPI.shared.setProviderAndWait(provider: InMemoryProvider(flags: InMemoryTestFlags.all()))
        let client = OpenFeatureAPI.shared.getClient()
        let hook = StageRecordingHook()

        let returned = client.getDetails(
            key: "boolean-flag",
            defaultValue: false,
            options: FlagEvaluationOptions(hooks: [hook]))

        let after = hook.invocation(.after)?.details as? FlagEvaluationDetails<Bool>
        let finally = hook.invocation(.finally)?.details as? FlagEvaluationDetails<Bool>
        XCTAssertEqual(after?.flagKey, "boolean-flag")
        XCTAssertEqual(after?.value, true)
        XCTAssertEqual(after?.variant, "on")
        XCTAssertNil(after?.errorCode)
        XCTAssertEqual(after, returned)
        XCTAssertEqual(finally, returned)
    }

    func testFinallyReceivesTheErrorDetailsWhenEvaluationFails() {
        let provider = AlwaysBrokenProvider()
        let eventState = installProviderAndWaitForError(provider)
        let client = OpenFeatureAPI.shared.getClient()
        let hook = StageRecordingHook()

        let returned = client.getDetails(
            key: "missing",
            defaultValue: true,
            options: FlagEvaluationOptions(hooks: [hook]))

        let finally = hook.invocation(.finally)?.details as? FlagEvaluationDetails<Bool>
        XCTAssertNil(hook.invocation(.after))
        XCTAssertEqual(finally?.value, true)
        XCTAssertEqual(finally?.errorCode, .flagNotFound)
        XCTAssertEqual(finally?.reason, Reason.error.rawValue)
        XCTAssertEqual(finally, returned)
        XCTAssertNotNil(eventState)
    }

    // MARK: - Error

    func testErrorStageReceivesTheThrownError() {
        let provider = AlwaysBrokenProvider()
        let eventState = installProviderAndWaitForError(provider)
        let client = OpenFeatureAPI.shared.getClient()
        let hook = StageRecordingHook()

        _ = client.getValue(key: "missing", defaultValue: false, options: FlagEvaluationOptions(hooks: [hook]))

        let error = hook.invocation(.error)?.error as? OpenFeatureError
        XCTAssertEqual(error?.errorCode(), .flagNotFound)
        XCTAssertNotNil(eventState)
    }

    func testErrorStageReceivesProviderNotReadyWhenNoProviderIsSet() async {
        await OpenFeatureAPI.shared.clearProviderAndWait()
        let client = OpenFeatureAPI.shared.getClient()
        let hook = StageRecordingHook()

        _ = client.getValue(key: "key", defaultValue: false, options: FlagEvaluationOptions(hooks: [hook]))

        let error = hook.invocation(.error)?.error as? OpenFeatureError
        XCTAssertEqual(error?.errorCode(), .providerNotReady)
        XCTAssertEqual(hook.invocations.map(\.stage), [.before, .error, .finally])
    }

    func testPlainSwiftErrorFromProviderReachesErrorStageAsGeneralError() async {
        await OpenFeatureAPI.shared.setProviderAndWait(provider: PlainErrorProvider())
        let client = OpenFeatureAPI.shared.getClient()
        let hook = StageRecordingHook()

        let details = client.getDetails(
            key: "key",
            defaultValue: false,
            options: FlagEvaluationOptions(hooks: [hook]))

        XCTAssertEqual(details.errorCode, .general)
        XCTAssertEqual(details.errorMessage, "\(PlainError())")
        XCTAssertNotNil(hook.invocation(.error)?.error as? PlainError)
        XCTAssertEqual(hook.invocations.map(\.stage), [.before, .error, .finally])
        XCTAssertTrue(hook.invocation(.before)?.hookData === hook.invocation(.error)?.hookData)
        XCTAssertTrue(hook.invocation(.before)?.hookData === hook.invocation(.finally)?.hookData)
    }

    // MARK: - Context fields

    func testEveryStageReceivesEvaluationContextAndMetadata() async {
        let provider = InMemoryProvider(flags: InMemoryTestFlags.all())
        await OpenFeatureAPI.shared.setProviderAndWait(
            provider: provider,
            initialContext: MutableContext(targetingKey: "user-1"))
        let client = OpenFeatureAPI.shared.getClient(name: "payload-client", version: "1.2.3")
        let hook = StageRecordingHook()

        _ = client.getValue(key: "boolean-flag", defaultValue: false, options: FlagEvaluationOptions(hooks: [hook]))

        XCTAssertEqual(hook.invocations.map(\.stage), [.before, .after, .finally])
        for invocation in hook.invocations {
            XCTAssertEqual(invocation.flagKey, "boolean-flag")
            XCTAssertEqual(invocation.type, .boolean)
            XCTAssertEqual(invocation.defaultValue as? Bool, false)
            XCTAssertEqual(invocation.evaluationContext?.getTargetingKey(), "user-1")
            XCTAssertEqual(invocation.clientMetadata?.name, "payload-client")
            XCTAssertEqual(invocation.providerMetadata?.name, provider.metadata.name)
        }
    }

    func testProviderMetadataIsAPlaceholderWhenNoProviderIsSet() async {
        await OpenFeatureAPI.shared.clearProviderAndWait()
        let client = OpenFeatureAPI.shared.getClient()
        let hook = StageRecordingHook()

        _ = client.getValue(key: "key", defaultValue: false, options: FlagEvaluationOptions(hooks: [hook]))

        let before = hook.invocation(.before)
        XCTAssertNotNil(before?.providerMetadata)
        XCTAssertNil(before?.providerMetadata?.name)
    }

    // MARK: - Hints

    func testHintsReachEveryStageUnchanged() async {
        await OpenFeatureAPI.shared.setProviderAndWait(provider: NoOpProvider())
        let client = OpenFeatureAPI.shared.getClient()
        let hook = StageRecordingHook()
        let options = FlagEvaluationOptions(hooks: [hook], hookHints: ["trace": "abc-123", "attempt": 2])

        _ = client.getValue(key: "key", defaultValue: false, options: options)

        XCTAssertEqual(hook.invocations.map(\.stage), [.before, .after, .finally])
        for invocation in hook.invocations {
            XCTAssertEqual(invocation.hints.count, 2)
            XCTAssertEqual(invocation.hints["trace"] as? String, "abc-123")
            XCTAssertEqual(invocation.hints["attempt"] as? Int, 2)
        }
    }

    func testHintsReachTheErrorStage() {
        let provider = AlwaysBrokenProvider()
        let eventState = installProviderAndWaitForError(provider)
        let client = OpenFeatureAPI.shared.getClient()
        let hook = StageRecordingHook()
        let options = FlagEvaluationOptions(hooks: [hook], hookHints: ["trace": "abc-123"])

        _ = client.getValue(key: "missing", defaultValue: false, options: options)

        XCTAssertEqual(hook.invocation(.error)?.hints["trace"] as? String, "abc-123")
        XCTAssertEqual(hook.invocation(.finally)?.hints["trace"] as? String, "abc-123")
        XCTAssertNotNil(eventState)
    }

    func testHintsDefaultToEmpty() async {
        await OpenFeatureAPI.shared.setProviderAndWait(provider: NoOpProvider())
        let client = OpenFeatureAPI.shared.getClient()
        let hook = StageRecordingHook()
        client.addHooks(hook)

        _ = client.getValue(key: "key", defaultValue: false)

        XCTAssertEqual(hook.invocations.count, 3)
        XCTAssertTrue(hook.invocations.allSatisfy { $0.hints.isEmpty })
    }

    // MARK: - Type-agnostic hooks (the README's CorrelationIDHook pattern)

    func testHookSupportingAllTypesRunsForEveryFlagValueType() async {
        await OpenFeatureAPI.shared.setProviderAndWait(provider: NoOpProvider())
        let client = OpenFeatureAPI.shared.getClient()
        let hook = StageRecordingHook()
        hook.supportsAllTypes = true
        client.addHooks(hook)

        _ = client.getValue(key: "key", defaultValue: false)
        _ = client.getValue(key: "key", defaultValue: "")
        _ = client.getValue(key: "key", defaultValue: Int64(0))
        _ = client.getValue(key: "key", defaultValue: 0.0)
        _ = client.getValue(key: "key", defaultValue: Value.null)

        let befores = hook.invocations(.before)
        XCTAssertEqual(befores.map(\.type), [.boolean, .string, .integer, .double, .object])
        XCTAssertEqual(hook.invocations(.after).count, 5)
        XCTAssertEqual(hook.invocations(.finally).count, 5)
        XCTAssertEqual(Set(befores.map { ObjectIdentifier($0.hookData) }).count, 5)
        XCTAssertEqual(befores[1].defaultValue as? String, "")
        XCTAssertEqual(befores[2].defaultValue as? Int64, 0)
        XCTAssertEqual(befores[4].defaultValue as? Value, .null)
    }

    func testBoolHookDoesNotRunForOtherTypesByDefault() async {
        await OpenFeatureAPI.shared.setProviderAndWait(provider: NoOpProvider())
        let client = OpenFeatureAPI.shared.getClient()
        let hook = StageRecordingHook()
        client.addHooks(hook)

        _ = client.getValue(key: "key", defaultValue: "")
        XCTAssertTrue(hook.invocations.isEmpty)

        _ = client.getValue(key: "key", defaultValue: false)
        XCTAssertEqual(hook.invocations.count, 3)
    }

    // MARK: - Lifetime

    func testHookDataIsReleasedOnceEvaluationCompletes() async {
        await OpenFeatureAPI.shared.setProviderAndWait(provider: NoOpProvider())
        let client = OpenFeatureAPI.shared.getClient()
        let hook = WeakHookDataHook()

        _ = client.getValue(key: "key", defaultValue: false, options: FlagEvaluationOptions(hooks: [hook]))

        XCTAssertTrue(hook.sawHookData)
        XCTAssertNil(hook.lastHookData, "the SDK must not retain hook data after the evaluation")
    }

    func testHookDataIsReleasedAfterFailedEvaluation() async {
        await OpenFeatureAPI.shared.clearProviderAndWait()
        let client = OpenFeatureAPI.shared.getClient()
        let hook = WeakHookDataHook()

        _ = client.getValue(key: "key", defaultValue: false, options: FlagEvaluationOptions(hooks: [hook]))

        XCTAssertTrue(hook.sawHookData)
        XCTAssertNil(hook.lastHookData, "the SDK must not retain hook data after a failed evaluation")
    }
}

/// An error that is not an `OpenFeatureError`, so the client has to map it to `.general`.
private struct PlainError: Error {}

/// A ready provider whose boolean evaluation throws a plain Swift error.
private final class PlainErrorProvider: NoOpProvider {
    override func getBooleanEvaluation(key: String, defaultValue: Bool, context: EvaluationContext?) throws
        -> ProviderEvaluation<Bool>
    {
        throw PlainError()
    }
}

/// Holds its hook data only weakly, so a test can check the SDK released it once the evaluation returned.
private final class WeakHookDataHook: Hook {
    typealias HookValue = Bool

    private(set) var sawHookData = false
    weak var lastHookData: HookData?

    func before<HookValue>(ctx: HookContext<HookValue>, hints: [String: Any]) {
        sawHookData = true
        lastHookData = ctx.hookData
    }
}
