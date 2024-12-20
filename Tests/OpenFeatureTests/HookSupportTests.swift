import Foundation
import XCTest

@testable import OpenFeature

final class HookSupportTests: XCTestCase {
    func testShouldAlwaysCallGenericHook() throws {
        let metadata = OpenFeatureAPI.shared.getClient().metadata
        let hook = BooleanHookMock()
        let hookContext: HookContext<Bool> = HookContext(
            flagKey: "flagKey",
            type: .boolean,
            defaultValue: false,
            ctx: MutableContext(),
            clientMetadata: metadata,
            providerMetadata: NoOpProvider().metadata)

        let hookSupport = HookSupport()

        hookSupport.beforeHooks(
            flagValueType: .boolean,
            hookCtx: hookContext,
            hooks: [hook],
            hints: [:])
        try hookSupport.afterHooks(
            flagValueType: .boolean,
            hookCtx: hookContext,
            details: FlagEvaluationDetails(flagKey: "", value: false),
            hooks: [hook],
            hints: [:])
        hookSupport.errorHooks(
            flagValueType: .boolean,
            hookCtx: hookContext,
            error: OpenFeatureError.invalidContextError,
            hooks: [hook],
            hints: [:])
        hookSupport.finallyHooks(
            flagValueType: .boolean,
            hookCtx: hookContext,
            hooks: [hook],
            hints: [:])

        XCTAssertEqual(hook.beforeCalled, 1)
        XCTAssertEqual(hook.afterCalled, 1)
        XCTAssertEqual(hook.errorCalled, 1)
        XCTAssertEqual(hook.finallyCalled, 1)
    }
}
