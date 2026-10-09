import Foundation
import XCTest

@testable import OpenFeature

final class HookSupportTests: XCTestCase {
    private let hints: [String: Any] = [:]
    private let details = FlagEvaluationDetails(flagKey: "", value: false)
    private let error = OpenFeatureError.invalidContextError

    func testShouldAlwaysCallGenericHook() {
        let hook = BooleanHookMock()
        let hooksWithContext = [pair(hook, makeContext())]
        let hookSupport = HookSupport()

        runAllStages(hookSupport, hooksWithContext)

        XCTAssertEqual(hook.beforeCalled, 1)
        XCTAssertEqual(hook.afterCalled, 1)
        XCTAssertEqual(hook.errorCalled, 1)
        XCTAssertEqual(hook.finallyCalled, 1)
    }

    func testBeforeRunsInReverseOrderAndOtherStagesInRegistrationOrder() {
        var order: [String] = []
        let first = BooleanHookMock(prefix: "first") { order.append($0) }
        let second = BooleanHookMock(prefix: "second") { order.append($0) }
        let hooksWithContext = [pair(first, makeContext()), pair(second, makeContext())]
        let hookSupport = HookSupport()

        hookSupport.beforeHooks(hooksWithContext: hooksWithContext, hints: hints)
        XCTAssertEqual(order, ["second before", "first before"])

        order.removeAll()
        hookSupport.afterHooks(hooksWithContext: hooksWithContext, details: details, hints: hints)
        XCTAssertEqual(order, ["first after", "second after"])

        order.removeAll()
        hookSupport.errorHooks(hooksWithContext: hooksWithContext, error: error, hints: hints)
        XCTAssertEqual(order, ["first error", "second error"])

        order.removeAll()
        hookSupport.finallyHooks(hooksWithContext: hooksWithContext, details: details, hints: hints)
        XCTAssertEqual(order, ["first finally", "second finally"])
    }

    func testEveryStageReceivesTheHookOwnContext() {
        let dataA = HookData()
        let dataB = HookData()
        let hookA = HookDataSpyHook<Bool>()
        let hookB = HookDataSpyHook<Bool>()
        let hooksWithContext = [
            pair(hookA, makeContext(hookData: dataA)),
            pair(hookB, makeContext(hookData: dataB)),
        ]
        let hookSupport = HookSupport()

        runAllStages(hookSupport, hooksWithContext)

        XCTAssertEqual(hookA.seenHookData.count, 4)
        XCTAssertTrue(hookA.seenHookData.allSatisfy { $0 === dataA })
        XCTAssertEqual(hookB.seenHookData.count, 4)
        XCTAssertTrue(hookB.seenHookData.allSatisfy { $0 === dataB })
    }

    func testValueWrittenInBeforeIsVisibleInEveryLaterStage() {
        var afterValue: Int?
        var errorValue: Int?
        var finallyValue: Int?
        let hook = HookDataSpyHook<Bool>(
            onBefore: { $0["span"] = 42 },
            onAfter: { afterValue = $0["span"] as? Int },
            onError: { errorValue = $0["span"] as? Int },
            onFinally: { finallyValue = $0["span"] as? Int })
        let hooksWithContext = [pair(hook, makeContext())]
        let hookSupport = HookSupport()

        runAllStages(hookSupport, hooksWithContext)

        XCTAssertEqual(afterValue, 42)
        XCTAssertEqual(errorValue, 42)
        XCTAssertEqual(finallyValue, 42)
    }

    func testHooksDoNotSeeEachOtherData() {
        var seenByA: Set<String> = []
        var seenByB: Set<String> = []
        let hookA = HookDataSpyHook<Bool>(
            onBefore: { $0["a"] = true },
            onFinally: { seenByA = $0.keys })
        let hookB = HookDataSpyHook<Bool>(
            onBefore: { $0["b"] = true },
            onFinally: { seenByB = $0.keys })
        let hooksWithContext = [pair(hookA, makeContext()), pair(hookB, makeContext())]
        let hookSupport = HookSupport()

        runAllStages(hookSupport, hooksWithContext)

        XCTAssertEqual(seenByA, ["a"])
        XCTAssertEqual(seenByB, ["b"])
    }

    func testEmptyHookListRunsNothing() {
        let hookSupport = HookSupport()
        let hooksWithContext: [HookSupport.HookWithContext<Bool>] = []

        runAllStages(hookSupport, hooksWithContext)
    }

    // MARK: - Helpers

    private func makeContext(hookData: HookData = HookData()) -> HookContext<Bool> {
        HookContext(
            flagKey: "flagKey",
            type: .boolean,
            defaultValue: false,
            ctx: MutableContext(),
            clientMetadata: OpenFeatureAPI.shared.getClient().metadata,
            providerMetadata: NoOpProvider().metadata,
            hookData: hookData)
    }

    private func pair(_ hook: any Hook, _ ctx: HookContext<Bool>) -> HookSupport.HookWithContext<Bool> {
        (hook: hook, ctx: ctx)
    }

    private func runAllStages(_ hookSupport: HookSupport, _ hooksWithContext: [HookSupport.HookWithContext<Bool>]) {
        hookSupport.beforeHooks(hooksWithContext: hooksWithContext, hints: hints)
        hookSupport.afterHooks(hooksWithContext: hooksWithContext, details: details, hints: hints)
        hookSupport.errorHooks(hooksWithContext: hooksWithContext, error: error, hints: hints)
        hookSupport.finallyHooks(hooksWithContext: hooksWithContext, details: details, hints: hints)
    }
}
