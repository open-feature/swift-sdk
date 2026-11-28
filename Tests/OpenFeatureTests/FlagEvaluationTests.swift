import Combine
import Foundation
import XCTest

@testable import OpenFeature
import OpenFeatureIsolated

final class FlagEvaluationTests: XCTestCase {
    /// A fresh API instance per test: XCTest creates a new test-case object for every test
    /// method, so tests share no state and need no setUp reset of the shared singleton.
    private let api = OpenFeatureAPI.isolated()
    func testSingletonPersists() {
        // Deliberately the global singleton: each access returns the same instance.
        XCTAssertTrue(OpenFeatureAPI.shared === OpenFeatureAPI.shared)
    }

    func testApiSetsProvider() async {
        let provider = NoOpProvider()
        await api.setProviderAndWait(provider: provider)
        XCTAssertTrue((api.getProvider() as? NoOpProvider) === provider)
    }

    func testProviderMetadata() async {
        await api.setProviderAndWait(provider: DoSomethingProvider())
        XCTAssertEqual(api.getProviderMetadata()?.name, DoSomethingProvider.name)
    }

    func testHooksPersist() {
        let hook1 = BooleanHookMock()
        let hook2 = BooleanHookMock()

        api.addHooks(hooks: hook1)

        XCTAssertEqual(api.getHooks().count, 1)

        api.addHooks(hooks: hook2)
        XCTAssertEqual(api.getHooks().count, 2)
    }

    func testNamedClient() {
        let client = api.getClient(name: "test", version: nil)
        XCTAssertEqual((client as? OpenFeatureClient)?.name, "test")
    }

    func testClientHooksPersist() {
        let hook1 = BooleanHookMock()
        let hook2 = BooleanHookMock()

        let client = api.getClient()
        client.addHooks(hook1)

        XCTAssertEqual(client.hooks.count, 1)

        client.addHooks(hook2)
        XCTAssertEqual(client.hooks.count, 2)
    }

    func testSimpleFlagEvaluation() async {
        let provider = DoSomethingProvider()

        await api.setProviderAndWait(provider: provider)
        let client = api.getClient()
        let key = "key"
        XCTAssertEqual(client.getValue(key: key, defaultValue: false), true)
        XCTAssertEqual(client.getValue(key: key, defaultValue: false), true)
        XCTAssertEqual(
            client.getValue(
                key: key, defaultValue: false, options: FlagEvaluationOptions()), true)

        XCTAssertEqual(client.getValue(key: key, defaultValue: "test"), "tset")
        XCTAssertEqual(client.getValue(key: key, defaultValue: "test"), "tset")
        XCTAssertEqual(
            client.getValue(
                key: key, defaultValue: "test", options: FlagEvaluationOptions()), "tset")

        XCTAssertEqual(client.getValue(key: key, defaultValue: 4), 400)
        XCTAssertEqual(client.getValue(key: key, defaultValue: 4), 400)
        XCTAssertEqual(
            client.getValue(key: key, defaultValue: 4, options: FlagEvaluationOptions()),
            400)

        XCTAssertEqual(client.getValue(key: key, defaultValue: 0.4), 40.0)
        XCTAssertEqual(client.getValue(key: key, defaultValue: 0.4), 40.0)
        XCTAssertEqual(
            client.getValue(key: key, defaultValue: 0.4, options: FlagEvaluationOptions()),
            40.0)

        var value: Value = client.getValue(key: key, defaultValue: .structure([:]))
        XCTAssertEqual(value, .null)
        value = client.getValue(key: key, defaultValue: .structure([:]))
        XCTAssertEqual(value, .null)
        value = client.getValue(key: key, defaultValue: .structure([:]), options: FlagEvaluationOptions())
        XCTAssertEqual(value, .null)
    }

    func testDetailedFlagEvaluation() async {
        let provider = DoSomethingProvider()

        await api.setProviderAndWait(provider: provider)
        let client = api.getClient()
        let key = "key"
        let booleanDetails = FlagEvaluationDetails(
            flagKey: key, value: true, flagMetadata: DoSomethingProvider.flagMetadataMap, variant: nil)
        XCTAssertEqual(client.getDetails(key: key, defaultValue: false), booleanDetails)
        XCTAssertEqual(client.getDetails(key: key, defaultValue: false), booleanDetails)
        XCTAssertEqual(
            client.getDetails(
                key: key, defaultValue: false, options: FlagEvaluationOptions()), booleanDetails)

        let stringDetails = FlagEvaluationDetails(
            flagKey: key, value: "tset", flagMetadata: DoSomethingProvider.flagMetadataMap, variant: nil)
        XCTAssertEqual(client.getDetails(key: key, defaultValue: "test"), stringDetails)
        XCTAssertEqual(client.getDetails(key: key, defaultValue: "test"), stringDetails)
        XCTAssertEqual(
            client.getDetails(
                key: key, defaultValue: "test", options: FlagEvaluationOptions()), stringDetails)

        let integerDetails = FlagEvaluationDetails(
            flagKey: key, value: Int64(400), flagMetadata: DoSomethingProvider.flagMetadataMap, variant: nil)
        XCTAssertEqual(client.getDetails(key: key, defaultValue: 4), integerDetails)
        XCTAssertEqual(client.getDetails(key: key, defaultValue: 4), integerDetails)
        XCTAssertEqual(
            client.getDetails(
                key: key, defaultValue: 4, options: FlagEvaluationOptions()), integerDetails)

        let doubleDetails = FlagEvaluationDetails(
            flagKey: key, value: 40.0, flagMetadata: DoSomethingProvider.flagMetadataMap, variant: nil)
        XCTAssertEqual(client.getDetails(key: key, defaultValue: 0.4), doubleDetails)
        XCTAssertEqual(client.getDetails(key: key, defaultValue: 0.4), doubleDetails)
        XCTAssertEqual(
            client.getDetails(
                key: key, defaultValue: 0.4, options: FlagEvaluationOptions()), doubleDetails)

        let objectDetails = FlagEvaluationDetails(
            flagKey: key, value: Value.null, flagMetadata: DoSomethingProvider.flagMetadataMap, variant: nil)
        XCTAssertEqual(client.getDetails(key: key, defaultValue: .structure([:])), objectDetails)
        XCTAssertEqual(
            client.getDetails(key: key, defaultValue: .structure([:])), objectDetails)
        XCTAssertEqual(
            client.getDetails(
                key: key, defaultValue: .structure([:]), options: FlagEvaluationOptions()),
            objectDetails)
    }

    func testHooksAreFired() async {
        let provider = NoOpProvider()

        await api.setProviderAndWait(provider: provider)

        let client = api.getClient()

        let clientHook = BooleanHookMock()
        let invocationHook = BooleanHookMock()

        client.addHooks(clientHook)
        _ = client.getValue(
            key: "key",
            defaultValue: false,
            options: FlagEvaluationOptions(hooks: [invocationHook]))

        XCTAssertEqual(clientHook.beforeCalled, 1)
        XCTAssertEqual(invocationHook.beforeCalled, 1)
    }

    func testBrokenProvider() {
        let provider = AlwaysBrokenProvider()
        let readyExpectation = XCTestExpectation(description: "Ready")
        let errorExpectation = XCTestExpectation(description: "Error")
        let staleExpectation = XCTestExpectation(description: "Stale")
        let eventState = provider.observe().sink { event in
            switch event {
            case .ready:
                readyExpectation.fulfill()
            case .error:
                errorExpectation.fulfill()
            case .stale:
                staleExpectation.fulfill()
            default:
                XCTFail("Unexpected event")
            }
        }
        api.setProvider(provider: provider)
        wait(for: [errorExpectation], timeout: 5)

        let client = api.getClient()

        XCTAssertFalse(client.getValue(key: "testkey", defaultValue: false))
        let details = client.getDetails(key: "testkey", defaultValue: false)

        XCTAssertEqual(details.errorCode, .flagNotFound)
        XCTAssertEqual(details.reason, Reason.error.rawValue)
        XCTAssertEqual(details.errorMessage, "Could not find flag for key: testkey")
        XCTAssertNotNil(eventState)
    }

    func testBrokenProviderThrowsFatal() {
        let provider = AlwaysBrokenProvider()
        provider.throwFatal = true
        let fatalExpectation = XCTestExpectation(description: "NotReady")

        let eventState = provider.observe().sink { event in
            switch event {
            case .error:
                fatalExpectation.fulfill()
            default:
                XCTFail("Unexpected event")
            }
        }
        api.setProvider(provider: provider)
        wait(for: [fatalExpectation], timeout: 5)

        let client = api.getClient()

        XCTAssertFalse(client.getValue(key: "testkey", defaultValue: false))
        let details = client.getDetails(key: "testkey", defaultValue: false)

        XCTAssertEqual(details.errorCode, .providerFatal)
        XCTAssertEqual(details.reason, Reason.error.rawValue)
        XCTAssertEqual(details.errorMessage, "A fatal error occurred in the provider: Always broken")
        XCTAssertNotNil(eventState)
    }

    func testClientMetadata() {
        let client1 = api.getClient()
        XCTAssertNil(client1.metadata.name)

        let client = api.getClient(name: "test", version: nil)
        XCTAssertEqual(client.metadata.name, "test")
    }

    func testFlagMetadata() {
        api.setProvider(provider: DoSomethingProvider())
        let client = api.getClient()
        let details = client.getDetails(key: "testkey", defaultValue: false)

        // These test values are hard coded for all evaluations from the DoSomethingProvider
        XCTAssertEqual(details.flagMetadata["int-metadata"]?.asInteger(), 99)
        XCTAssertEqual(details.flagMetadata["double-metadata"]?.asDouble(), 98.4)
        XCTAssertEqual(details.flagMetadata["string-metadata"]?.asString(), "hello-world")
        XCTAssertEqual(details.flagMetadata["boolean-metadata"]?.asBoolean(), true)

        // Non existent key
        XCTAssertNil(details.flagMetadata["non-existent-key"])

        // Invalid mapping an int to string returns nil
        XCTAssertNil(details.flagMetadata["int-metadata"]?.asString())
    }
}
