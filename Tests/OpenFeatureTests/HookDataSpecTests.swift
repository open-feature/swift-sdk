import Foundation
import XCTest

@testable import OpenFeature

/// Hook data through the client, end to end: created before `before`, carried through every later stage of the
/// same hook, and fresh on every evaluation (spec 4.1.1, 4.3.2, 4.6.1).
final class HookDataSpecTests: XCTestCase {
    override func setUp() async throws {
        try await super.setUp()
        await OpenFeatureAPI.shared.clearProviderAndWait()
        OpenFeatureAPI.shared.clearHooks()
    }

    // MARK: - Lifecycle across stages

    func testHookDataIsEmptyWhenBeforeRuns() async {
        await OpenFeatureAPI.shared.setProviderAndWait(provider: NoOpProvider())
        let client = OpenFeatureAPI.shared.getClient()
        var wasEmpty: Bool?
        let hook = HookDataSpyHook<Bool>()
        hook.onBefore = { wasEmpty = $0.isEmpty }

        _ = client.getValue(key: "key", defaultValue: false, options: FlagEvaluationOptions(hooks: [hook]))

        XCTAssertEqual(wasEmpty, true)
    }

    func testHookDataIsSharedAcrossStagesForSameHook() async {
        await OpenFeatureAPI.shared.setProviderAndWait(provider: NoOpProvider())
        let client = OpenFeatureAPI.shared.getClient()
        var afterValue: Int?
        var finallyValue: Int?
        let hook = HookDataSpyHook<Bool>(
            onBefore: { $0["span"] = 42 },
            onAfter: { afterValue = $0["span"] as? Int },
            onFinally: { finallyValue = $0["span"] as? Int })

        _ = client.getValue(key: "key", defaultValue: false, options: FlagEvaluationOptions(hooks: [hook]))

        XCTAssertEqual(afterValue, 42)
        XCTAssertEqual(finallyValue, 42)
        XCTAssertEqual(hook.seenHookData.count, 3)
        XCTAssertTrue(hook.seenHookData.allSatisfy { $0 === hook.seenHookData[0] })
    }

    func testHookDataWrittenInAfterIsVisibleInFinally() async {
        await OpenFeatureAPI.shared.setProviderAndWait(provider: NoOpProvider())
        let client = OpenFeatureAPI.shared.getClient()
        var finallyValue: String?
        let hook = HookDataSpyHook<Bool>(
            onAfter: { $0["written-in-after"] = "yes" },
            onFinally: { finallyValue = $0["written-in-after"] as? String })

        _ = client.getValue(key: "key", defaultValue: false, options: FlagEvaluationOptions(hooks: [hook]))

        XCTAssertEqual(finallyValue, "yes")
    }

    func testHookDataCarriesReferenceTypeBetweenStages() async {
        await OpenFeatureAPI.shared.setProviderAndWait(provider: NoOpProvider())
        let client = OpenFeatureAPI.shared.getClient()
        var startedSpan: FakeSpan?
        var endedSpan: FakeSpan?
        let hook = HookDataSpyHook<Bool>(
            onBefore: { data in
                let span = FakeSpan()
                startedSpan = span
                data["span"] = span
            },
            onFinally: { data in
                let span = data["span"] as? FakeSpan
                span?.ended = true
                endedSpan = span
            })

        _ = client.getValue(key: "key", defaultValue: false, options: FlagEvaluationOptions(hooks: [hook]))

        XCTAssertNotNil(startedSpan)
        XCTAssertTrue(startedSpan === endedSpan)
        XCTAssertEqual(startedSpan?.ended, true)
    }

    func testHookContextCarriesEvaluationDetailsAlongsideHookData() async {
        await OpenFeatureAPI.shared.setProviderAndWait(provider: NoOpProvider())
        let client = OpenFeatureAPI.shared.getClient()
        var capturedFlagKey: String?
        var capturedType: FlagValueType?
        var capturedDefault: Bool?
        var capturedHookDataWasEmpty: Bool?
        let hook = CapturingContextHook { ctx in
            capturedFlagKey = ctx.flagKey
            capturedType = ctx.type
            capturedDefault = ctx.defaultValue
            capturedHookDataWasEmpty = ctx.hookData.isEmpty
        }

        _ = client.getValue(key: "the-flag", defaultValue: true, options: FlagEvaluationOptions(hooks: [hook]))

        XCTAssertEqual(capturedFlagKey, "the-flag")
        XCTAssertEqual(capturedType, .boolean)
        XCTAssertEqual(capturedDefault, true)
        XCTAssertEqual(capturedHookDataWasEmpty, true)
    }

    // MARK: - Error paths

    func testHookDataPersistsThroughErrorAndFinallyStages() {
        let provider = AlwaysBrokenProvider()
        let eventState = installProviderAndWaitForError(provider)
        let client = OpenFeatureAPI.shared.getClient()
        var errorValue: String?
        var finallyValue: String?
        var afterCalled = false
        let hook = HookDataSpyHook<Bool>(
            onBefore: { $0["trace"] = "from-before" },
            onAfter: { _ in afterCalled = true },
            onError: { errorValue = $0["trace"] as? String },
            onFinally: { finallyValue = $0["trace"] as? String })

        _ = client.getValue(key: "key", defaultValue: false, options: FlagEvaluationOptions(hooks: [hook]))

        XCTAssertFalse(afterCalled)
        XCTAssertEqual(errorValue, "from-before")
        XCTAssertEqual(finallyValue, "from-before")
        XCTAssertEqual(hook.seenHookData.count, 3)
        XCTAssertTrue(hook.seenHookData.allSatisfy { $0 === hook.seenHookData[0] })
        XCTAssertNotNil(eventState)
    }

    func testHookDataWrittenInErrorIsVisibleInFinally() {
        let provider = AlwaysBrokenProvider()
        let eventState = installProviderAndWaitForError(provider)
        let client = OpenFeatureAPI.shared.getClient()
        var finallyValue: String?
        let hook = HookDataSpyHook<Bool>(
            onError: { $0["written-in-error"] = "yes" },
            onFinally: { finallyValue = $0["written-in-error"] as? String })

        _ = client.getValue(key: "key", defaultValue: false, options: FlagEvaluationOptions(hooks: [hook]))

        XCTAssertEqual(finallyValue, "yes")
        XCTAssertNotNil(eventState)
    }

    func testHookDataPersistsThroughErrorWhenNoProviderIsSet() async {
        await OpenFeatureAPI.shared.clearProviderAndWait()
        let client = OpenFeatureAPI.shared.getClient()
        var errorValue: String?
        var finallyValue: String?
        let hook = HookDataSpyHook<Bool>(
            onBefore: { $0["trace"] = "from-before" },
            onError: { errorValue = $0["trace"] as? String },
            onFinally: { finallyValue = $0["trace"] as? String })

        let details = client.getDetails(
            key: "key",
            defaultValue: false,
            options: FlagEvaluationOptions(hooks: [hook]))

        XCTAssertEqual(details.errorCode, .providerNotReady)
        XCTAssertEqual(errorValue, "from-before")
        XCTAssertEqual(finallyValue, "from-before")
        XCTAssertEqual(hook.seenHookData.count, 3)
    }

    // MARK: - Fresh per evaluation

    func testHookDataIsFreshForEachEvaluation() async {
        await OpenFeatureAPI.shared.setProviderAndWait(provider: NoOpProvider())
        let client = OpenFeatureAPI.shared.getClient()
        var leakedFromPreviousEvaluation = false
        let hook = HookDataSpyHook<Bool>()
        hook.onBefore = { data in
            if data["seen"] != nil {
                leakedFromPreviousEvaluation = true
            }
            data["seen"] = true
        }
        let options = FlagEvaluationOptions(hooks: [hook])

        _ = client.getValue(key: "key", defaultValue: false, options: options)
        _ = client.getValue(key: "key", defaultValue: false, options: options)

        XCTAssertFalse(leakedFromPreviousEvaluation)
        XCTAssertEqual(hook.seenHookData.count, 6)
        let firstEvaluation = hook.seenHookData[0]
        let secondEvaluation = hook.seenHookData[3]
        XCTAssertTrue(hook.seenHookData[0..<3].allSatisfy { $0 === firstEvaluation })
        XCTAssertTrue(hook.seenHookData[3..<6].allSatisfy { $0 === secondEvaluation })
        XCTAssertFalse(firstEvaluation === secondEvaluation)
    }

    func testHookDataIsFreshForEachEvaluationOfDifferentFlags() async {
        await OpenFeatureAPI.shared.setProviderAndWait(provider: NoOpProvider())
        let client = OpenFeatureAPI.shared.getClient()
        let hook = HookDataSpyHook<Bool>()
        client.addHooks(hook)

        _ = client.getValue(key: "first", defaultValue: false)
        _ = client.getValue(key: "second", defaultValue: false)

        XCTAssertEqual(hook.seenHookData.count, 6)
        XCTAssertFalse(hook.seenHookData[0] === hook.seenHookData[3])
    }

    func testConcurrentEvaluationsGetSeparateHookData() async {
        await OpenFeatureAPI.shared.setProviderAndWait(provider: NoOpProvider())
        let client = OpenFeatureAPI.shared.getClient()
        let iterations = 64
        let lock = NSLock()
        var tokensReadInFinally: [UUID] = []
        let hook = HookDataSpyHook<Bool>(
            onBefore: { $0["token"] = UUID() },
            onFinally: { data in
                guard let token = data["token"] as? UUID else {
                    return
                }
                lock.withLock { tokensReadInFinally.append(token) }
            })
        let options = FlagEvaluationOptions(hooks: [hook])

        DispatchQueue.concurrentPerform(iterations: iterations) { _ in
            _ = client.getValue(key: "key", defaultValue: false, options: options)
        }

        XCTAssertEqual(tokensReadInFinally.count, iterations)
        XCTAssertEqual(Set(tokensReadInFinally).count, iterations)
        XCTAssertEqual(hook.seenHookData.count, iterations * 3)
        XCTAssertEqual(Set(hook.seenHookData.map { ObjectIdentifier($0) }).count, iterations)
    }
}

/// Stands in for an observability span: a reference type whose identity must survive from `before` to `finally`.
private final class FakeSpan {
    var ended = false
}

/// Captures the typed `HookContext<Bool>` handed to `before`, so a test can inspect every field at once.
private final class CapturingContextHook: Hook {
    typealias HookValue = Bool

    private let onBefore: (HookContext<Bool>) -> Void

    init(onBefore: @escaping (HookContext<Bool>) -> Void) {
        self.onBefore = onBefore
    }

    func before<HookValue>(ctx: HookContext<HookValue>, hints: [String: Any]) {
        if let ctx = ctx as? HookContext<Bool> {
            onBefore(ctx)
        }
    }
}
