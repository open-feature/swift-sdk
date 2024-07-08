import Foundation
import OpenFeature
import XCTest

final class ProviderEventsTests: XCTestCase {
    let provider = DoSomethingProvider()

    func testReadyEventSent() {
        let readyExpectation = XCTestExpectation(description: "Ready")
        let eventState =
            provider
            .observe()
            .filter { event in
                event == ProviderEvent.ready
            }
            .sink { _ in
                readyExpectation.fulfill()
            }
        OpenFeatureAPI.shared.setProvider(provider: provider)
        wait(for: [readyExpectation], timeout: 5)
        XCTAssertNotNil(eventState)
    }
}
