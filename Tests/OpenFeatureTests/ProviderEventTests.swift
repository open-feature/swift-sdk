import Combine
import Foundation
import OpenFeature
import XCTest

final class ProviderEventTests: XCTestCase {
    func testObservingProviderEventInitialization() {
        let mockEventHandler = EventHandler()
        let provider = MockProvider(
            initialize: { _ in throw MockProvider.MockProviderError.message("Mock error") },
            observe: { mockEventHandler.observe() }
        )
        var cancellables = Set<AnyCancellable>()
        let api = OpenFeatureAPI()
        api.setProvider(provider: provider)
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
            initialize: { _ in },
            observe: { mockEventHandler.observe() }
        )
        var cancellables = Set<AnyCancellable>()
        let api = OpenFeatureAPI()
        api.setProvider(provider: provider)
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
            if let event {
                receivedEvents.append(event)
            }
            receivedEvents.count == mockEvents.count ? eventsExpectation.fulfill() : nil
        }
        .store(in: &cancellables)
        mockEvents.forEach { event in
            mockEventHandler.send(event)
        }
        wait(for: [eventsExpectation], timeout: 5)
        XCTAssertEqual(receivedEvents, mockEvents)
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
            XCTAssertTrue(mockMetadata["Bool"]?.asBoolean() == true)
            XCTAssertTrue(mockMetadata["Int"]?.asInteger() == 42)
            XCTAssertTrue(mockMetadata["Double"]?.asDouble() == 10.5)
            XCTAssertTrue(mockMetadata["String"]?.asString() == "Hello World")
        default:
            XCTFail("Unexpected event type")
        }
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
