import Combine
import XCTest

@testable import OpenFeature

final class MultiProviderTests: XCTestCase {
    func testEvaluationWithMultipleProvidersDefaultStrategy_MultipleTypes() throws {
        // Test first provider missing flag results in second provider being evaluated
        let mockKey = "testKey"
        let mockProviderBoolValue = true
        let mockProviderStringValue = "testString"
        let mockProviderIntegerValue: Int64 = 1
        let mockProviderDoubleValue: Double = 1.0
        let mockProviderObjectValue: Value = Value.structure(["testKey": Value.string("testValue")])
        // First provider doesn't have the flag and test using all types
        let mockProvider1 = MockProvider(
            getBooleanEvaluation: { flag, defaultValue, _ in
                throw OpenFeatureError.flagNotFoundError(key: flag)
            },
            getStringEvaluation: { flag, defaultValue, _ in
                throw OpenFeatureError.flagNotFoundError(key: flag)
            },
            getIntegerEvaluation: { flag, defaultValue, _ in
                throw OpenFeatureError.flagNotFoundError(key: flag)
            },
            getDoubleEvaluation: { flag, defaultValue, _ in
                throw OpenFeatureError.flagNotFoundError(key: flag)
            },
            getObjectEvaluation: { flag, defaultValue, _ in
                throw OpenFeatureError.flagNotFoundError(key: flag)
            }
        )
        // Second provider has the flag and test using all types
        let mockProvider2 = MockProvider(
            getBooleanEvaluation: { flag, defaultValue, _ in
                if flag == mockKey {
                    return ProviderEvaluation(value: mockProviderBoolValue)
                } else {
                    return ProviderEvaluation(value: defaultValue, errorCode: .flagNotFound)
                }
            },
            getStringEvaluation: { flag, defaultValue, _ in
                if flag == mockKey {
                    return ProviderEvaluation(value: mockProviderStringValue)
                } else {
                    return ProviderEvaluation(value: defaultValue, errorCode: .flagNotFound)
                }
            },
            getIntegerEvaluation: { flag, defaultValue, _ in
                if flag == mockKey {
                    return ProviderEvaluation(value: mockProviderIntegerValue)
                } else {
                    return ProviderEvaluation(value: defaultValue, errorCode: .flagNotFound)
                }
            },
            getDoubleEvaluation: { flag, defaultValue, _ in
                if flag == mockKey {
                    return ProviderEvaluation(value: mockProviderDoubleValue)
                } else {
                    return ProviderEvaluation(value: defaultValue, errorCode: .flagNotFound)
                }
            },
            getObjectEvaluation: { flag, defaultValue, _ in
                if flag == mockKey {
                    return ProviderEvaluation(value: mockProviderObjectValue)
                } else {
                    return ProviderEvaluation(value: defaultValue, errorCode: .flagNotFound)
                }
            }
        )
        let multiProvider = MultiProvider(providers: [mockProvider1, mockProvider2])
        
        // Expect the second provider's value to be returned
        let boolResult = try multiProvider.getBooleanEvaluation(key: mockKey, defaultValue: false, context: MutableContext())
        XCTAssertEqual(boolResult.value, mockProviderBoolValue)
        let stringResult = try multiProvider.getStringEvaluation(key: mockKey, defaultValue: "", context: MutableContext())
        XCTAssertEqual(stringResult.value, mockProviderStringValue)
        let integerResult = try multiProvider.getIntegerEvaluation(key: mockKey, defaultValue: 0, context: MutableContext())
        XCTAssertEqual(integerResult.value, mockProviderIntegerValue)
        let doubleResult = try multiProvider.getDoubleEvaluation(key: mockKey, defaultValue: 0.0, context: MutableContext())
        XCTAssertEqual(doubleResult.value, mockProviderDoubleValue)
        let objectResult = try multiProvider.getObjectEvaluation(key: mockKey, defaultValue: .null, context: MutableContext())
        XCTAssertEqual(objectResult.value, mockProviderObjectValue)
    }
    
    func testEvaluationWithMultipleProvidersAndFirstMatchStrategy_FirstProviderHasFlag() throws {
        let mockKey = "test-key"
        let mockProvider1Value = true
        let mockProvider1 = MockProvider(
            getBooleanEvaluation: { flag, defaultValue, _ in
                return ProviderEvaluation(value: mockProvider1Value)
            }
        )
        let mockProvider2 = MockProvider(
            getBooleanEvaluation: { key, _, _ in
                return ProviderEvaluation(value: !mockProvider1Value)
            }
        )
        let multiProvider = MultiProvider(
            providers: [mockProvider1, mockProvider2],
            strategy: FirstMatchStrategy()
        )
        
        let boolResult = try multiProvider.getBooleanEvaluation(key: mockKey, defaultValue: false, context: MutableContext())
        XCTAssertEqual(boolResult.value, mockProvider1Value)
    }
    
    func testEvaluationWithMultipleProvidersAndFirstMatchStrategy_FlagNotFound() throws {
        let mockKey = "test-key"
        let mockProviderValue = true
        let mockProvider1 = MockProvider(
            getBooleanEvaluation: { key, _, _ in
                throw OpenFeatureError.flagNotFoundError(key: key)
            }
        )
        let mockProvider2 = MockProvider(
            getBooleanEvaluation: { flag, defaultValue, _ in
                if flag == mockKey {
                    return ProviderEvaluation(value: mockProviderValue)
                } else {
                    return ProviderEvaluation(value: defaultValue, errorCode: .flagNotFound)
                }
            }
        )
        let multiProvider = MultiProvider(
            providers: [mockProvider1, mockProvider2],
            strategy: FirstMatchStrategy()
        )
        
        let boolResult = try multiProvider.getBooleanEvaluation(key: mockKey, defaultValue: false, context: MutableContext())
        XCTAssertEqual(boolResult.value, mockProviderValue)
    }
    
    func testEvaluationWithMultipleProvidersAndFirstMatchStrategy_AllProvidersMissingFlag() throws {
        let mockKey = "test-key"
        let mockProvider1 = MockProvider(
            getBooleanEvaluation: { flag, defaultValue, _ in
                return ProviderEvaluation(value: defaultValue, errorCode: .flagNotFound)
            }
        )
        let mockProvider2 = MockProvider(
            getBooleanEvaluation: { key, _, _ in
                throw OpenFeatureError.flagNotFoundError(key: key)
            }
        )
        let multiProvider = MultiProvider(
            providers: [mockProvider1, mockProvider2],
            strategy: FirstMatchStrategy()
        )
        
        let result = try multiProvider.getBooleanEvaluation(key: mockKey, defaultValue: false, context: MutableContext())
        XCTAssertTrue(result.errorCode == .flagNotFound)
    }
    
    func testEvaluationWithMultipleProvidersAndFirstMatchStrategy_Throws() throws {
        let mockKey = "test-key"
        let mockProvider1 = MockProvider(
            getBooleanEvaluation: { flag, defaultValue, _ in
                return ProviderEvaluation(value: defaultValue, errorCode: .flagNotFound)
            }
        )
        let mockProvider2 = MockProvider(
            getBooleanEvaluation: { _, _, _ in
                throw OpenFeatureError.generalError(message: "test error")
            }
        )
        let multiProvider = MultiProvider(
            providers: [mockProvider1, mockProvider2],
            strategy: FirstMatchStrategy()
        )
        
        do {
            _ = try multiProvider.getBooleanEvaluation(key: mockKey, defaultValue: false, context: MutableContext())
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertEqual(error as? OpenFeatureError, OpenFeatureError.generalError(message: "test error"))
        }
    }
    
    func testEvaluationWithMultipleProvidersAndFirstSuccessfulStrategy_HandlesError() throws {
        let mockKey = "test-key"
        let mockProvider1Value = true
        let mockProvider1 = MockProvider(
            getBooleanEvaluation: { _, _, _ in
                throw OpenFeatureError.generalError(message: "test error")
            }
        )
        let mockProvider2 = MockProvider(
            getBooleanEvaluation: { flag, defaultValue, _ in
                return ProviderEvaluation(value: mockProvider1Value)
            }
        )
        let multiProvider = MultiProvider(
            providers: [mockProvider1, mockProvider2],
            strategy: FirstSuccessfulStrategy()
        )
        
        let boolResult = try multiProvider.getBooleanEvaluation(key: mockKey, defaultValue: false, context: MutableContext())
        XCTAssertEqual(boolResult.value, mockProvider1Value)
        XCTAssertNil(boolResult.errorCode)
    }
    
    func testEvaluationWithMultipleProvidersAndFirstSuccessfulStrategy_MissingFlag() throws {
        let mockKey = "test-key"
        let mockProvider1 = MockProvider(
            getBooleanEvaluation: { flag, defaultValue, _ in
                return ProviderEvaluation(value: defaultValue, errorCode: .flagNotFound)
            }
        )
        let mockProvider2 = MockProvider(
            getBooleanEvaluation: { flag, defaultValue, _ in
                return ProviderEvaluation(value: defaultValue, errorCode: .flagNotFound)
            }
        )
        let multiProvider = MultiProvider(
            providers: [mockProvider1, mockProvider2],
            strategy: FirstSuccessfulStrategy()
        )
        
        do {
            let boolResult = try multiProvider.getBooleanEvaluation(key: mockKey, defaultValue: false, context: MutableContext())
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertTrue(error as? OpenFeatureError == OpenFeatureError.flagNotFoundError(key: mockKey))
        }
    }
    
    func testObserveWithMultipleProviders() {
        let mockEvent1 = ProviderEvent.ready
        let mockProvider1 = MockProvider(
            observe: {
                return Just(mockEvent1).eraseToAnyPublisher()
            }
        )
        let mockEvent2 = ProviderEvent.contextChanged
        let mockProvider2 = MockProvider(
            observe: {
                return Just(mockEvent2).eraseToAnyPublisher()
            }
        )
        let multiProvider = MultiProvider(providers: [mockProvider1, mockProvider2])
        let fulfillment = XCTestExpectation(description: "Received provider events")
        let mockEvents = [mockEvent1, mockEvent2]
        var receivedEvents: [ProviderEvent] = []
        let observation = multiProvider.observe().sink(receiveValue: { event in
            if let event {
                receivedEvents.append(event)
            }
            if receivedEvents.count == mockEvents.count {
                fulfillment.fulfill()
            }
        })
        wait(for: [fulfillment], timeout: 2)
        observation.cancel()
        XCTAssertEqual(receivedEvents, mockEvents)
    }
}
