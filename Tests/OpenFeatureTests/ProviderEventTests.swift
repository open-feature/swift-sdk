import Combine
import Foundation
import OpenFeature
import XCTest

final class ProviderEventTests: XCTestCase {
    func testObservingProviderEventInitialization() {
        let mockEventHandler = EventHandler()
        let provider = MockProvider(
            initialize: { _ in
                // Emit error event before throwing
                mockEventHandler.send(.error(ProviderEventDetails(message: "Mock error")))
                throw MockProvider.MockProviderError.message("Mock error")
            },
            observe: { mockEventHandler.observe() }
        )
        var cancellables = Set<AnyCancellable>()
        let api = OpenFeatureAPI()
        let expectation = XCTestExpectation(description: "Error")
        api
            .observe()
            .sink { event in
                switch event {
                case .error(let details):
                    if let details {
                        XCTAssertEqual(details.message, "Mock error")
                    } else {
                        XCTFail("Expected non-nil details")
                    }
                    expectation.fulfill()
                default:
                    break
                }
            }
            .store(in: &cancellables)
        api.setProvider(provider: provider)
        wait(for: [expectation], timeout: 5)
        cancellables.removeAll()
    }

    func testObservingProviderEventsWithDetails() {
        let mockEventHandler = EventHandler()
        let provider = MockProvider(
            initialize: { _ in
                // Emit ready event after initialization
                mockEventHandler.send(.ready())
            },
            observe: { mockEventHandler.observe() }
        )
        var cancellables = Set<AnyCancellable>()
        let api = OpenFeatureAPI()
        let readyExpectation = XCTestExpectation(description: "Ready")
        api
            .observe()
            .sink { event in
                switch event {
                case .ready:
                    readyExpectation.fulfill()
                default:
                    break
                }
            }
            .store(in: &cancellables)
        api.setProvider(provider: provider)
        wait(for: [readyExpectation], timeout: 5)

        let eventsExpectation = XCTestExpectation(description: "Events")
        var receivedEvents: [ProviderEvent] = []
        let mockEvents = [mockReady]
        api
            .observe()
            .sink { event in
                receivedEvents.append(event)
                if receivedEvents.count == mockEvents.count { eventsExpectation.fulfill() }
            }
            .store(in: &cancellables)
        mockEvents.forEach { event in
            mockEventHandler.send(event)
        }
        wait(for: [eventsExpectation], timeout: 5)
        // May receive an initial .ready(nil) when the provider was set; ensure we got the sent event(s)
        XCTAssertTrue(receivedEvents.contains(mockReady), "Expected mockReady in received: \(receivedEvents)")
        cancellables.removeAll()
    }

    func testProviderEventDetails() throws {
        let mockFlags = ["Flag1", "Flag2"]
        let mockMessage = "Mock Message"
        let mockError: ErrorCode = .general
        let mockMetadata: EventMetadata = [
            "Bool": .boolean(true),
            "Int": .integer(42),
            "Double": .double(10.5),
            "String": .string("Hello World"),
        ]
        let eventDetails = ProviderEventDetails(
            flagsChanged: mockFlags,
            message: mockMessage,
            errorCode: mockError,
            eventMetadata: mockMetadata
        )

        let event = ProviderEvent.configurationChanged(eventDetails)
        switch event {
        case .configurationChanged(let details):
            let details = try XCTUnwrap(details)
            XCTAssertEqual(details.flagsChanged, mockFlags)
            XCTAssertEqual(details.message, mockMessage)
            XCTAssertEqual(details.errorCode, mockError)
            XCTAssertEqual(details.eventMetadata, mockMetadata)
            // Validate metadata types and values
            XCTAssertEqual(mockMetadata["Bool"]?.asBoolean(), true)
            XCTAssertEqual(mockMetadata["Int"]?.asInteger(), 42)
            XCTAssertEqual(mockMetadata["Double"]?.asDouble(), 10.5)
            XCTAssertEqual(mockMetadata["String"]?.asString(), "Hello World")
        default:
            XCTFail("Unexpected event type")
        }
    }

    /// **Expected behavior: does not deadlock.** Uses a provider that synchronously replays `.ready`
    /// on subscription (CurrentValueSubject). That would previously cause the event to be delivered
    /// on the same thread that holds the API's state lock; a handler calling `getProviderStatus()`
    /// would then deadlock. The SDK must run handlers on a dedicated queue so this completes.
    func testEventHandlerCallingBackIntoAPIDoesNotDeadlock() async {
        let api = OpenFeatureAPI()

        let eventSubject = CurrentValueSubject<ProviderEvent, Never>(.ready(nil))
        // Keeping the `observe:` label avoids ambiguous closure matching against other closure parameters.
        // swiftlint:disable trailing_closure
        let provider = MockProvider(
            observe: { eventSubject.eraseToAnyPublisher() }
        )
        // swiftlint:enable trailing_closure

        let noDeadlockExpectation = XCTestExpectation(
            description: "Event handler called getProviderStatus() and returned without deadlock")
        var cancellables = Set<AnyCancellable>()

        api
            .observe()
            .sink { _ in
                _ = api.getProviderStatus()
                noDeadlockExpectation.fulfill()
            }
            .store(in: &cancellables)

        api.setProvider(provider: provider)

        await fulfillment(of: [noDeadlockExpectation], timeout: 5)
        cancellables.removeAll()
    }

    // MARK: - Helpers for Provider Events
    var mockReady: ProviderEvent = .ready(
        ProviderEventDetails(
            flagsChanged: nil,
            message: nil,
            errorCode: nil,
            eventMetadata: [:]
        ))
    var mockError: ProviderEvent = .error(
        ProviderEventDetails(
            flagsChanged: nil,
            message: "general error message",
            errorCode: .general,
            eventMetadata: [:]
        ))
    var mockConfigurationChanged: ProviderEvent = .configurationChanged(
        ProviderEventDetails(
            flagsChanged: ["Flag1", "Flag2"],
            message: nil,
            errorCode: nil,
            eventMetadata: [
                "Mock String": .string("some details"),
                "Mock Bool": .boolean(true),
                "Mock Double": .double(10),
                "Mock Integer": .integer(100),
            ]
        )
    )
    var mockStale: ProviderEvent = .stale(
        ProviderEventDetails(
            flagsChanged: nil,
            message: nil,
            errorCode: nil,
            eventMetadata: [:]
        )
    )
    var mockReconciling: ProviderEvent = .reconciling(
        ProviderEventDetails(
            flagsChanged: nil,
            message: nil,
            errorCode: nil,
            eventMetadata: [:]
        )
    )
    var mockContextChanged: ProviderEvent = .contextChanged(
        ProviderEventDetails(
            flagsChanged: ["Flag1", "Flag2"],
            message: nil,
            errorCode: nil,
            eventMetadata: [:]
        )
    )
}
