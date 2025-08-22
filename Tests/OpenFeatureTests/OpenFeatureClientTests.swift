import Foundation
import XCTest

@testable import OpenFeature

final class OpenFeatureClientTests: XCTestCase {
    func testShouldNowThrowIfHookHasDifferentTypeArgument() {
        let readyExpectation = XCTestExpectation(description: "Ready")
        let eventState = OpenFeatureAPI.shared.observe().sink { event in
            switch event {
            case .ready:
                readyExpectation.fulfill()
            default:
                break
            }
        }
        OpenFeatureAPI.shared.setProvider(provider: DoSomethingProvider())
        OpenFeatureAPI.shared.addHooks(hooks: BooleanHookMock())

        let client = OpenFeatureAPI.shared.getClient()
        wait(for: [readyExpectation], timeout: 2)

        let stringDetails = client.getDetails(key: "key", defaultValue: "test")
        XCTAssertEqual(stringDetails.value, "tset")

        let intDetails: FlagEvaluationDetails<Int64> = client.getDetails(
            key: "key", defaultValue: 123
        )
        XCTAssertEqual(intDetails.value, 12_300)

        let doubleDetails = client.getDetails(key: "key", defaultValue: 123.1)
        XCTAssertEqual(doubleDetails.value, 12_310)
        XCTAssertNotNil(eventState)
    }
}
