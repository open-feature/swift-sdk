import Foundation
import OpenFeature
import XCTest

final class ProviderEventsTests: XCTestCase {
    let provider = DoSomethingProvider()

    func testReadyEventEmitted() {
        provider.addHandler(
            observer: self, selector: #selector(readyEventEmitted(notification:)), event: .ready
        )

        OpenFeatureAPI.shared.setProvider(provider: provider)
        wait(for: [readyExpectation], timeout: 5)
    }

    // MARK: Event Handlers
    let readyExpectation = XCTestExpectation(description: "Ready")

    func readyEventEmitted(notification: NSNotification) {
        readyExpectation.fulfill()

        let maybeProvider = notification.userInfo?[providerEventDetailsKeyProvider]
        guard let eventProvider = maybeProvider as? DoSomethingProvider else {
            XCTFail("Provider not passed in notification")
            return
        }
        XCTAssertEqual(eventProvider.metadata.name, provider.metadata.name)
    }
}
