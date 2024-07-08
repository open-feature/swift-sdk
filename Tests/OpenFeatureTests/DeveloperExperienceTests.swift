import XCTest

@testable import OpenFeature

final class DeveloperExperienceTests: XCTestCase {
    func testNoProviderSet() {
        OpenFeatureAPI.shared.clearProvider()
        let client = OpenFeatureAPI.shared.getClient()

        let flagValue = client.getValue(key: "test", defaultValue: "no-op")
        XCTAssertEqual(flagValue, "no-op")
    }

    func testSimpleBooleanFlag() {
        OpenFeatureAPI.shared.setProvider(provider: NoOpProvider())
        let client = OpenFeatureAPI.shared.getClient()

        let flagValue = client.getValue(key: "test", defaultValue: false)
        XCTAssertFalse(flagValue)
    }

    func testObserveGlobalEvents() {
        let notReadyExpectation = XCTestExpectation(description: "NotReady")
        let readyExpectation = XCTestExpectation(description: "Ready")
        var eventState = OpenFeatureAPI.shared.observe().sink { event in
            switch event {
            case .notReady:
                notReadyExpectation.fulfill()
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

    func testSetProviderAndWait() async {
        let notReadyExpectation = XCTestExpectation(description: "NotReady")
        let readyExpectation = XCTestExpectation(description: "Ready")
        let errorExpectation = XCTestExpectation(description: "Error")
        withExtendedLifetime(
            OpenFeatureAPI.shared.observe().sink { event in
                switch event {
                case .notReady:
                    notReadyExpectation.fulfill()
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

            let eventHandler = EventHandler()
            let provider = InjectableEventHandlerProvider(eventHandler: eventHandler)
            Task {
                await OpenFeatureAPI.shared.setProviderAndWait(provider: provider)
                wait(for: [readyExpectation], timeout: 1)
                initCompleteExpectation.fulfill()
            }
            wait(for: [notReadyExpectation], timeout: 1)
            eventHandler.send(.ready)
            wait(for: [initCompleteExpectation], timeout: 1)

            let errorProviderExpectation = XCTestExpectation()
            let brokenProvider = AlwaysBrokenProvider()
            Task {
                await OpenFeatureAPI.shared.setProviderAndWait(provider: brokenProvider)
                wait(for: [errorExpectation], timeout: 2)
                errorProviderExpectation.fulfill()
            }

            eventHandler.send(.error)
            wait(for: [errorProviderExpectation], timeout: 2)
        }
    }

    func testClientHooks() {
        OpenFeatureAPI.shared.setProvider(provider: NoOpProvider())
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

    func testEvalHooks() {
        OpenFeatureAPI.shared.setProvider(provider: NoOpProvider())
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

    func testBrokenProvider() {
        OpenFeatureAPI.shared.setProvider(provider: AlwaysBrokenProvider())
        let client = OpenFeatureAPI.shared.getClient()

        let details = client.getDetails(key: "test", defaultValue: false)

        XCTAssertEqual(details.errorCode, .flagNotFound)
        XCTAssertEqual(details.errorMessage, "Could not find flag for key: test")
        XCTAssertEqual(details.reason, Reason.error.rawValue)
    }
}
