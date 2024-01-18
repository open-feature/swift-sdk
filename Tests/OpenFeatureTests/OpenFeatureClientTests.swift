import Foundation
import XCTest

@testable import OpenFeature

final class OpenFeatureClientTests: XCTestCase {
    func testShouldNowThrowIfHookHasDifferentTypeArgument() {
        OpenFeatureAPI.shared.setProvider(provider: DoSomethingProvider())
        OpenFeatureAPI.shared.addHooks(hooks: BooleanHookMock())

        let client = OpenFeatureAPI.shared.getClient()

        let stringDetails = client.getDetails(key: "key", defaultValue: "test")
        XCTAssertEqual(stringDetails.value, "tset")

        let intDetails: FlagEvaluationDetails<Int64> = client.getDetails(
            key: "key", defaultValue: 123
        )
        XCTAssertEqual(intDetails.value, 12_300)

        let doubleDetails = client.getDetails(key: "key", defaultValue: 123.1)
        XCTAssertEqual(doubleDetails.value, 12_310)
    }

    // MARK: Event Handlers
    private var eventExpectations: [ProviderEvent: XCTestExpectation] = [:]

    func setupExpectations() {
        ProviderEvent.allCases.forEach { event in
            eventExpectations[event] = XCTestExpectation(description: event.rawValue)
        }
    }

    func eventEmitted(notification: NSNotification) {
        guard let providerEvent = ProviderEvent(rawValue: notification.name.rawValue) else {
            XCTFail("Unexpected provider event: \(notification.name)")
            return
        }

        guard let expectation = eventExpectations[providerEvent] else {
            XCTFail("No expectation for provider event: \(providerEvent)")
            return
        }

        expectation.fulfill()
    }
}
