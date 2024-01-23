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
        let readyExpectation = XCTestExpectation(description: "Ready")
        let errorExpectation = XCTestExpectation(description: "Error")
        let staleExpectation = XCTestExpectation(description: "Stale")
        var eventState = OpenFeatureAPI.shared.observe().sink { event in
            switch event {
            case ProviderEvent.ready:
                readyExpectation.fulfill()
            case ProviderEvent.error:
                errorExpectation.fulfill()
            case ProviderEvent.stale:
                staleExpectation.fulfill()
            default:
                XCTFail("Unexpected event")
            }
        }
        let provider = DoSomethingProvider()
        OpenFeatureAPI.shared.setProvider(provider: provider)
        wait(for: [readyExpectation], timeout: 5)

        OpenFeatureAPI.shared.clearProvider()

        // Clearing the Provider shouldn't send further global events from it
        eventState = OpenFeatureAPI.shared.observe().sink { _ in
            XCTFail("Unexpected event")
        }

        provider.initialize(initialContext: MutableContext(attributes: ["Test": Value.string("Test")]))

        XCTAssertNotNil(eventState)
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
