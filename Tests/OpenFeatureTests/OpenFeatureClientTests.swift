import Foundation
import XCTest

@testable import OpenFeature
import OpenFeatureIsolated

final class OpenFeatureClientTests: XCTestCase {
    /// A fresh API instance per test: XCTest creates a new test-case object for every test
    /// method, so tests share no state and need no setUp reset of the shared singleton.
    private let api = OpenFeatureAPI.isolated()
    func testShouldNowThrowIfHookHasDifferentTypeArgument() {
        let readyExpectation = XCTestExpectation(description: "Ready")
        let eventState = api.observe().sink { event in
            switch event {
            case .ready:
                readyExpectation.fulfill()
            default:
                break
            }
        }
        api.setProvider(provider: DoSomethingProvider())
        api.addHooks(hooks: BooleanHookMock())

        let client = api.getClient()
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

    func testTrackPassesStoredEvaluationContextToProvider() async {
        var receivedKey: String?
        var receivedContext: (any EvaluationContext)?
        var receivedDetails: (any TrackingEventDetails)?
        let onTrack = { (key: String, evaluationContext: EvaluationContext?, details: TrackingEventDetails?) in
            receivedKey = key
            receivedContext = evaluationContext
            receivedDetails = details
        }
        let storedContext = ImmutableContext(
            targetingKey: "user-1",
            structure: ImmutableStructure(attributes: ["plan": .string("premium"), "num": .double(10)])
        )
        await api.setProviderAndWait(provider: MockProvider(track: onTrack))
        await api.setEvaluationContextAndWait(evaluationContext: storedContext)

        api.getClient().track(
            key: "test",
            details: ImmutableTrackingEventDetails(value: 5)
        )

        XCTAssertEqual(receivedKey, "test")
        XCTAssertEqual(receivedContext?.getTargetingKey(), storedContext.getTargetingKey())
        XCTAssertEqual(receivedContext?.getValue(key: "plan"), .string("premium"))
        XCTAssertEqual(receivedContext?.getValue(key: "num"), .double(10))
        XCTAssertEqual(receivedDetails?.getValue(), 5)
    }
}
