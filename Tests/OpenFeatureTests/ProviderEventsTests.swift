import Foundation
import OpenFeature
import XCTest

final class ProviderEventsTests: XCTestCase {
    let provider = DoSomethingProvider()
    let readyExpectation = XCTestExpectation(description: "Ready")

    func testReadyEventEmitted() {
        let sink = provider
            .observe()
            .filter { event in
                event == ProviderEvent.ready
            }
            .sink { _ in
                self.readyExpectation.fulfill()
            }
        OpenFeatureAPI.shared.setProvider(provider: provider)
        wait(for: [readyExpectation], timeout: 5)
        XCTAssertNotNil(sink)
    }
}
