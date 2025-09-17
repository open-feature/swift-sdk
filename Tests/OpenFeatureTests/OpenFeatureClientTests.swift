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
    
    func testMergeEvaluationContext_ApiEmptyAndInvocationNil_ThenEmpty() async {
        let client = OpenFeatureClient(openFeatureApi: OpenFeatureAPI.shared, name: nil, version: nil)
        await OpenFeatureAPI.shared.setEvaluationContextAndWait(evaluationContext: ImmutableContext())
        let result = client.mergeEvaluationContext(nil)
        XCTAssertTrue(result?.getTargetingKey().isEmpty == true)
        XCTAssertTrue(result?.keySet().isEmpty == true)
    }
    
    func testMergeEvaluationContext_ApiContextAndInvocationNil_ThenApiContext() async {
        let client = OpenFeatureClient(openFeatureApi: OpenFeatureAPI.shared, name: nil, version: nil)
        let context = ImmutableContext(targetingKey: "api", structure: ImmutableStructure(attributes: ["bool": .boolean(true)]))
        await OpenFeatureAPI.shared.setEvaluationContextAndWait(evaluationContext: context)
        let result = client.mergeEvaluationContext(nil)
        XCTAssertEqual(result?.getTargetingKey(), context.getTargetingKey())
        XCTAssertEqual(result?.asMap(), context.asMap())
    }
    
    func testMergeEvaluationContext_ApiNilAndInvocationContext_ThenInvocationContext() {
        let client = OpenFeatureClient(openFeatureApi: OpenFeatureAPI.shared, name: nil, version: nil)
        let context = ImmutableContext(targetingKey: "invocation", structure: ImmutableStructure(attributes: ["bool": .boolean(true)]))
        let result = client.mergeEvaluationContext(context)
        XCTAssertEqual(result?.getTargetingKey(), context.getTargetingKey())
        XCTAssertEqual(result?.asMap(), context.asMap())
    }
    
    func testMergeEvaluationContext_ApiContextAndInvocationContext_ThenMergedContext() async {
        let client = OpenFeatureClient(openFeatureApi: OpenFeatureAPI.shared, name: nil, version: nil)
        let apiContext = ImmutableContext(
            targetingKey: "api",
            structure: ImmutableStructure(attributes: ["bool": .boolean(true), "num": .integer(1)])
        )
        let invocationContext = ImmutableContext(
            targetingKey: "invocation",
            structure: ImmutableStructure(attributes: ["bool": .boolean(false), "string": .string("test")])
        )
        await OpenFeatureAPI.shared.setEvaluationContextAndWait(evaluationContext: apiContext)
        let result = client.mergeEvaluationContext(invocationContext)
        XCTAssertEqual(result?.getTargetingKey(), invocationContext.getTargetingKey())
        XCTAssertEqual(result?.keySet().count, 3)
        XCTAssertEqual(result?.getValue(key: "bool"), .boolean(false))
        XCTAssertEqual(result?.getValue(key: "num"), .integer(1))
        XCTAssertEqual(result?.getValue(key: "string"), .string("test"))
    }
}
