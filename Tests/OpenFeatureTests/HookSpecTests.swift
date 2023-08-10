import Foundation
import XCTest

@testable import OpenFeature

final class HookSpecTests: XCTestCase {
    override func setUp() {
        super.setUp()

        OpenFeatureAPI.shared.addHandler(
            observer: self, selector: #selector(readyEventEmitted(notification:)), event: .ready
        )

        OpenFeatureAPI.shared.addHandler(
            observer: self, selector: #selector(errorEventEmitted(notification:)), event: .error
        )
    }

    func testNoErrorHookCalled() {
        OpenFeatureAPI.shared.setProvider(provider: NoOpProvider())
        wait(for: [readyExpectation], timeout: 5)

        let client = OpenFeatureAPI.shared.getClient()
        let hook = BooleanHookMock()
        let feo = FlagEvaluationOptions(hooks: [hook])

        _ = client.getValue(
            key: "key",
            defaultValue: false,
            options: feo)

        XCTAssertEqual(hook.beforeCalled, 1)
        XCTAssertEqual(hook.afterCalled, 1)
        XCTAssertEqual(hook.errorCalled, 0)
        XCTAssertEqual(hook.finallyAfterCalled, 1)
    }

    func testErrorHookButNoAfterCalled() {
        OpenFeatureAPI.shared.setProvider(provider: AlwaysBrokenProvider())
        wait(for: [errorExpectation], timeout: 5)

        let client = OpenFeatureAPI.shared.getClient()
        let hook = BooleanHookMock()

        _ = client.getValue(
            key: "key",
            defaultValue: false,
            options: FlagEvaluationOptions(hooks: [hook]))

        XCTAssertEqual(hook.beforeCalled, 1)
        XCTAssertEqual(hook.afterCalled, 0)
        XCTAssertEqual(hook.errorCalled, 1)
        XCTAssertEqual(hook.finallyAfterCalled, 1)
    }

    func testHookEvaluationOrder() {
        var evalOrder: [String] = []
        let addEval: (String) -> Void = { eval in
            evalOrder.append(eval)
        }

        let providerMock = NoOpProviderMock(hooks: [
            BooleanHookMock(prefix: "provider", addEval: addEval)
        ])
        OpenFeatureAPI.shared.setProvider(provider: providerMock)
        wait(for: [readyExpectation], timeout: 5)

        OpenFeatureAPI.shared.addHooks(hooks: BooleanHookMock(prefix: "api", addEval: addEval))
        let client = OpenFeatureAPI.shared.getClient()
        client.addHooks(BooleanHookMock(prefix: "client", addEval: addEval))
        let flagOptions = FlagEvaluationOptions(hooks: [
            BooleanHookMock(prefix: "invocation", addEval: addEval)
        ])

        _ = client.getValue(key: "key", defaultValue: false, options: flagOptions)

        XCTAssertEqual(
            evalOrder,
            [
                "api before",
                "client before",
                "invocation before",
                "provider before",
                "provider after",
                "invocation after",
                "client after",
                "api after",
                "provider finallyAfter",
                "invocation finallyAfter",
                "client finallyAfter",
                "api finallyAfter",
            ])
    }

    // MARK: Event Handlers
    let readyExpectation = XCTestExpectation(description: "Ready")

    func readyEventEmitted(notification: NSNotification) {
        readyExpectation.fulfill()
    }

    let errorExpectation = XCTestExpectation(description: "Error")

    func errorEventEmitted(notification: NSNotification) {
        errorExpectation.fulfill()
    }
}

extension HookSpecTests {
    class NoOpProviderMock: NoOpProvider {
        init(hooks: [any Hook]) {
            super.init()
            self.hooks.append(contentsOf: hooks)
        }
    }
}
