import XCTest

@testable import OpenFeature

final class DeveloperExperienceTests: XCTestCase {
    func testNoProviderSet() {
        OpenFeatureAPI.shared.clearProvider()
        let client = OpenFeatureAPI.shared.getClient()

        let flagValue = client.getValue(key: "test", defaultValue: "no-op")
        XCTAssertEqual(flagValue, "no-op")
    }

    func testSimpleBooleanFlag() async {
        await OpenFeatureAPI.shared.setProviderAndWait(provider: NoOpProvider())
        let client = OpenFeatureAPI.shared.getClient()

        let flagValue = client.getValue(key: "test", defaultValue: false)
        XCTAssertFalse(flagValue)
    }

    func testObserveGlobalEvents() {
        let readyExpectation = XCTestExpectation(description: "Ready")
        var eventState = OpenFeatureAPI.shared.observe().sink { event in
            switch event {
            case .ready:
                readyExpectation.fulfill()
            default:
                XCTFail("Unexpected event")
            }
        }
        let provider = DoSomethingProvider()
        OpenFeatureAPI.shared.setProvider(provider: provider)
        wait(for: [readyExpectation], timeout: 5)

        // Clearing the Provider shouldn't send further global events from it
        // Dropping the first event, which reflects the current state before clearing
        eventState = OpenFeatureAPI.shared.observe().dropFirst().sink { _ in
            XCTFail("Unexpected event")
        }
        OpenFeatureAPI.shared.clearProvider()
        provider.initialize(initialContext: MutableContext(attributes: ["Test": Value.string("Test")]))
        XCTAssertNotNil(eventState)
    }

    func testSetEvaluationContext() async {
        let contextChangedExpectation = XCTestExpectation(description: "Context Changed")
        let reconcilingExpectation = XCTestExpectation(description: "Reconciling")
        let observer = OpenFeatureAPI.shared.observe().sink { event in
            switch event {
            case .reconciling:
                reconcilingExpectation.fulfill()
            case .ready:
                break
            case .contextChanged:
                contextChangedExpectation.fulfill()
            default:
                XCTFail("Unexpected event")
            }
        }
        let semaphore = DispatchSemaphore(value: 0)
        await OpenFeatureAPI.shared.setProviderAndWait(provider: StaggeredProvider(onContextSetSemaphore: semaphore))
        Task {
            OpenFeatureAPI.shared.setEvaluationContext(evaluationContext: MutableContext(attributes: [:]))
        }
        await fulfillment(of: [reconcilingExpectation], timeout: 2)
        semaphore.signal()
        await fulfillment(of: [contextChangedExpectation], timeout: 2)
        XCTAssertNotNil(observer)
    }

    func testSetEvaluationContextAndWait() async {
        let reconcilingExpectation = XCTestExpectation(description: "Reconciling")
        let semaphore = DispatchSemaphore(value: 0)
        let ctx = MutableContext(attributes: ["test": .string("value")])
        let provider = StaggeredProvider(onContextSetSemaphore: semaphore)
        await OpenFeatureAPI.shared.setProviderAndWait(provider: provider)
        Task {
            await OpenFeatureAPI.shared.setEvaluationContextAndWait(evaluationContext: ctx)
            reconcilingExpectation.fulfill()
        }
        XCTAssertEqual(provider.activeContext.asMap(), MutableContext().asMap())
        semaphore.signal()
        await fulfillment(of: [reconcilingExpectation], timeout: 2)
        XCTAssertEqual(OpenFeatureAPI.shared.getEvaluationContext()?.asMap(), ctx.asMap())
        XCTAssertEqual(provider.activeContext.asMap(), ctx.asMap())
    }

    func testSetProviderAndWait() async {
        let readyExpectation = XCTestExpectation(description: "Ready")
        let errorExpectation = XCTestExpectation(description: "Error")
        withExtendedLifetime(
            OpenFeatureAPI.shared.observe().sink { event in
                switch event {
                case .ready:
                    readyExpectation.fulfill()
                case .error:
                    errorExpectation.fulfill()
                default:
                    XCTFail("Unexpected event")
                }
            }
        ) {
            let initCompleteExpectation = XCTestExpectation()

            let provider = DoSomethingProvider()
            Task {
                await OpenFeatureAPI.shared.setProviderAndWait(provider: provider)
                await fulfillment(of: [readyExpectation], timeout: 1)
                initCompleteExpectation.fulfill()
            }
            wait(for: [initCompleteExpectation], timeout: 1)

            let errorProviderExpectation = XCTestExpectation()
            let brokenProvider = AlwaysBrokenProvider()
            Task {
                await OpenFeatureAPI.shared.setProviderAndWait(provider: brokenProvider)
                await fulfillment(of: [errorExpectation], timeout: 2)
                errorProviderExpectation.fulfill()
            }
            wait(for: [errorProviderExpectation], timeout: 2)
        }
    }

    func testClientHooks() async {
        await OpenFeatureAPI.shared.setProviderAndWait(provider: NoOpProvider())
        let client = OpenFeatureAPI.shared.getClient()

        let booleanHook = BooleanHookMock()
        let intHook = IntHookMock()
        client.addHooks(booleanHook, intHook)

        _ = client.getValue(key: "string-test", defaultValue: "test")
        XCTAssertEqual(booleanHook.finallyAfterCalled, 0)
        XCTAssertEqual(intHook.finallyAfterCalled, 0)

        _ = client.getValue(key: "bool-test", defaultValue: false)
        XCTAssertEqual(booleanHook.finallyAfterCalled, 1)
        XCTAssertEqual(intHook.finallyAfterCalled, 0)

        _ = client.getValue(key: "int-test", defaultValue: 0) as Int64
        XCTAssertEqual(booleanHook.finallyAfterCalled, 1)
        XCTAssertEqual(intHook.finallyAfterCalled, 1)
    }

    func testEvalHooks() async {
        await OpenFeatureAPI.shared.setProviderAndWait(provider: NoOpProvider())
        let client = OpenFeatureAPI.shared.getClient()

        let booleanHook = BooleanHookMock()
        let intHook = IntHookMock()
        let options = FlagEvaluationOptions(hooks: [booleanHook, intHook])

        _ = client.getValue(key: "test", defaultValue: "test", options: options)
        XCTAssertEqual(booleanHook.finallyAfterCalled, 0)
        XCTAssertEqual(intHook.finallyAfterCalled, 0)

        _ = client.getValue(key: "test", defaultValue: false, options: options)
        XCTAssertEqual(booleanHook.finallyAfterCalled, 1)
        XCTAssertEqual(intHook.finallyAfterCalled, 0)

        _ = client.getValue(key: "test", defaultValue: 0, options: options) as Int64
        XCTAssertEqual(booleanHook.finallyAfterCalled, 1)
        XCTAssertEqual(intHook.finallyAfterCalled, 1)
    }

    func testBrokenProvider() async {
        await OpenFeatureAPI.shared.setProviderAndWait(provider: AlwaysBrokenProvider())
        let client = OpenFeatureAPI.shared.getClient()

        let details = client.getDetails(key: "test", defaultValue: false)

        XCTAssertEqual(details.errorCode, .flagNotFound)
        XCTAssertEqual(details.errorMessage, "Could not find flag for key: test")
        XCTAssertEqual(details.reason, Reason.error.rawValue)
    }

    func testThrowingProvider() async {
        await OpenFeatureAPI.shared.setProviderAndWait(provider: ThrowingProvider())
        let client = OpenFeatureAPI.shared.getClient()

        let details = client.getDetails(key: "test", defaultValue: false)

        XCTAssertEqual(details.errorCode, .providerFatal)
        XCTAssertEqual(details.errorMessage, "A fatal error occurred in the provider: unknown")
        XCTAssertEqual(details.reason, Reason.error.rawValue)
    }
}
