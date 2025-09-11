import Combine
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
        XCTAssertEqual(booleanHook.finallyCalled, 0)
        XCTAssertEqual(intHook.finallyCalled, 0)

        _ = client.getValue(key: "bool-test", defaultValue: false)
        XCTAssertEqual(booleanHook.finallyCalled, 1)
        XCTAssertEqual(intHook.finallyCalled, 0)

        _ = client.getValue(key: "int-test", defaultValue: 0) as Int64
        XCTAssertEqual(booleanHook.finallyCalled, 1)
        XCTAssertEqual(intHook.finallyCalled, 1)
    }

    func testEvalHooks() async {
        await OpenFeatureAPI.shared.setProviderAndWait(provider: NoOpProvider())
        let client = OpenFeatureAPI.shared.getClient()

        let booleanHook = BooleanHookMock()
        let intHook = IntHookMock()
        let options = FlagEvaluationOptions(hooks: [booleanHook, intHook])

        _ = client.getValue(key: "test", defaultValue: "test", options: options)
        XCTAssertEqual(booleanHook.finallyCalled, 0)
        XCTAssertEqual(intHook.finallyCalled, 0)

        _ = client.getValue(key: "test", defaultValue: false, options: options)
        XCTAssertEqual(booleanHook.finallyCalled, 1)
        XCTAssertEqual(intHook.finallyCalled, 0)

        _ = client.getValue(key: "test", defaultValue: 0, options: options) as Int64
        XCTAssertEqual(booleanHook.finallyCalled, 1)
        XCTAssertEqual(intHook.finallyCalled, 1)
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

    func testMultiProviderObserveEvents() async {
        let mockEvent1Subject = CurrentValueSubject<ProviderEvent?, Never>(nil)
        let mockEvent2Subject = CurrentValueSubject<ProviderEvent?, Never>(nil)
        // Create test providers that can emit events
        let eventEmittingProvider1 = MockProvider(
            initialize: { _ in mockEvent1Subject.send(.ready) },
            getBooleanEvaluation: { _, _, _ in throw OpenFeatureError.generalError(message: "test error") },
            observe: { mockEvent1Subject.eraseToAnyPublisher() }
        )
        let eventEmittingProvider2 = MockProvider(
            initialize: { _ in mockEvent2Subject.send(.ready) },
            getBooleanEvaluation: { _, _, _ in throw OpenFeatureError.generalError(message: "test error") },
            observe: { mockEvent2Subject.eraseToAnyPublisher() }
        )
        
        // Create MultiProvider with both providers
        let multiProvider = MultiProvider(providers: [eventEmittingProvider1, eventEmittingProvider2])
        
        // Set up expectations for different events
        let readyExpectation = XCTestExpectation(description: "Ready event received")
        let configChangedExpectation = XCTestExpectation(description: "Configuration changed event received")
        let errorExpectation = XCTestExpectation(description: "Error event received")
        
        var receivedEvents: [ProviderEvent] = []
        
        // Observe events from MultiProvider
        let observer = multiProvider.observe().sink { event in
            guard let event = event else { return }
            receivedEvents.append(event)
            
            switch event {
            case .ready:
                readyExpectation.fulfill()
            case .configurationChanged:
                configChangedExpectation.fulfill()
            case .error:
                errorExpectation.fulfill()
            default:
                break
            }
        }
        
        // Set the MultiProvider in OpenFeatureAPI to test integration
        await OpenFeatureAPI.shared.setProviderAndWait(provider: multiProvider)
        
        // Emit events from the first provider
        mockEvent1Subject.send(.ready)
        mockEvent1Subject.send(.configurationChanged)
        
        // Emit events from the second provider
        mockEvent2Subject.send(.error(errorCode: .general, message: "Test error"))
        
        // Wait for all events to be received
        await fulfillment(of: [readyExpectation, configChangedExpectation, errorExpectation], timeout: 2)
        
        // Verify that events from both providers were received
        XCTAssertTrue(receivedEvents.contains(.ready))
        XCTAssertTrue(receivedEvents.contains(.configurationChanged))
        XCTAssertTrue(receivedEvents.contains(.error(errorCode: .general, message: "Test error")))
        XCTAssertGreaterThanOrEqual(receivedEvents.count, 3)
        
        observer.cancel()
    }
}
