
import XCTest
import Combine
@testable import OpenFeature

class ConcurrencyRaceConditionTests: XCTestCase {

    override func setUp() {
        super.setUp()
        OpenFeatureAPI.shared.clearProvider()
    }

    func testConcurrentSetEvaluationContextRaceCondition() async throws {
        let provider = MockProvider()
        let readyExpectation = XCTestExpectation(description: "Ready")
        let cancellable = OpenFeatureAPI.shared.observe().sink { event in
            if case .ready = event {
                readyExpectation.fulfill()
            }
        }
        OpenFeatureAPI.shared.setProvider(provider: provider)
        await fulfillment(of: [readyExpectation], timeout: 2.0)

        let concurrentOperations = 100
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<concurrentOperations {
                group.addTask {
                    let ctx = ImmutableContext(
                        targetingKey: "user\(i)",
                        structure: ImmutableStructure(attributes: [
                            "id": .integer(Int64(i)),
                            "timestamp": .string("\(Date().timeIntervalSince1970)")
                        ])
                    )
                    
                    // This should trigger the race condition in updateContext
                    await OpenFeatureAPI.shared.setEvaluationContextAndWait(evaluationContext: ctx)
                }
            }
        }
        
        cancellable.cancel()
        XCTAssertTrue(true)
    }
}
