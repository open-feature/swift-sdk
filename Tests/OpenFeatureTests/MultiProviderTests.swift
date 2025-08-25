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
        let mockProviderObjectValue = Value.structure(["testKey": Value.string("testValue")])
        let mockError = OpenFeatureError.flagNotFoundError(key: mockKey)
        // First provider doesn't have the flag and test using all types
        let mockProvider1 = MultiProviderTestHelpers.mockThrowingProvider(error: mockError)
        // Second provider has the flag and test using all types
        let mockProvider2 = MultiProviderTestHelpers.mockTestProvider(
            values: MultiProviderTestHelpers.MockValues(
                mockKey: mockKey,
                mockProviderBoolValue: mockProviderBoolValue,
                mockProviderStringValue: mockProviderStringValue,
                mockProviderIntegerValue: mockProviderIntegerValue,
                mockProviderDoubleValue: mockProviderDoubleValue,
                mockProviderObjectValue: mockProviderObjectValue
            )
        )
        let multiProvider = MultiProvider(providers: [mockProvider1, mockProvider2])
        // Expect the second provider's value to be returned
        let boolResult = try multiProvider.getBooleanEvaluation(
            key: mockKey, defaultValue: false, context: MutableContext())
        XCTAssertEqual(boolResult.value, mockProviderBoolValue)
        let stringResult = try multiProvider.getStringEvaluation(
            key: mockKey, defaultValue: "", context: MutableContext())
        XCTAssertEqual(stringResult.value, mockProviderStringValue)
        let integerResult = try multiProvider.getIntegerEvaluation(
            key: mockKey, defaultValue: 0, context: MutableContext())
        XCTAssertEqual(integerResult.value, mockProviderIntegerValue)
        let doubleResult = try multiProvider.getDoubleEvaluation(
            key: mockKey, defaultValue: 0.0, context: MutableContext())
        XCTAssertEqual(doubleResult.value, mockProviderDoubleValue)
        let objectResult = try multiProvider.getObjectEvaluation(
            key: mockKey, defaultValue: .null, context: MutableContext())
        XCTAssertEqual(objectResult.value, mockProviderObjectValue)
    }

    func testEvaluationWithMultipleProvidersAndFirstMatchStrategy_FirstProviderHasFlag() throws {
        let mockKey = "test-key"
        let mockProvider1Value = true
        let mockProvider1 = MockProvider(
            initialize: { _ in },
            getBooleanEvaluation: { _, _, _ in ProviderEvaluation(value: mockProvider1Value) }
        )
        let mockProvider2 = MockProvider(
            initialize: { _ in },
            getBooleanEvaluation: { _, _, _ in ProviderEvaluation(value: !mockProvider1Value) }
        )
        let multiProvider = MultiProvider(
            providers: [mockProvider1, mockProvider2],
            strategy: FirstMatchStrategy()
        )

        let boolResult = try multiProvider.getBooleanEvaluation(
            key: mockKey, defaultValue: false, context: MutableContext())
        XCTAssertEqual(boolResult.value, mockProvider1Value)
    }

    func testEvaluationWithMultipleProvidersAndFirstMatchStrategy_FlagNotFound() throws {
        let mockKey = "test-key"
        let mockProviderValue = true
        let mockProvider1 = MockProvider(
            initialize: { _ in },
            getBooleanEvaluation: { key, _, _ in
                throw OpenFeatureError.flagNotFoundError(key: key)
            }
        )
        let mockProvider2 = MockProvider(
            initialize: { _ in },
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

        let boolResult = try multiProvider.getBooleanEvaluation(
            key: mockKey, defaultValue: false, context: MutableContext())
        XCTAssertEqual(boolResult.value, mockProviderValue)
    }

    func testEvaluationWithMultipleProvidersAndFirstMatchStrategy_AllProvidersMissingFlag() throws {
        let mockKey = "test-key"
        let mockProvider1 = MockProvider(
            initialize: { _ in },
            getBooleanEvaluation: { _, defaultValue, _ in
                return ProviderEvaluation(value: defaultValue, errorCode: .flagNotFound)
            }
        )
        let mockProvider2 = MockProvider(
            initialize: { _ in },
            getBooleanEvaluation: { key, _, _ in throw OpenFeatureError.flagNotFoundError(key: key) }
        )
        let multiProvider = MultiProvider(
            providers: [mockProvider1, mockProvider2],
            strategy: FirstMatchStrategy()
        )

        let result = try multiProvider.getBooleanEvaluation(
            key: mockKey,
            defaultValue: false,
            context: MutableContext()
        )
        XCTAssertTrue(result.errorCode == .flagNotFound)
    }

    func testEvaluationWithMultipleProvidersAndFirstMatchStrategy_Throws() throws {
        let mockKey = "test-key"
        let mockProvider1 = MockProvider(
            initialize: { _ in },
            getBooleanEvaluation: { _, defaultValue, _ in
                return ProviderEvaluation(value: defaultValue, errorCode: .flagNotFound)
            }
        )
        let mockProvider2 = MockProvider(
            initialize: { _ in },
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
            initialize: { _ in },
            getBooleanEvaluation: { _, _, _ in
                throw OpenFeatureError.generalError(message: "test error")
            }
        )
        let mockProvider2 = MockProvider(
            initialize: { _ in },
            getBooleanEvaluation: { _, _, _ in
                return ProviderEvaluation(value: mockProvider1Value)
            }
        )
        let multiProvider = MultiProvider(
            providers: [mockProvider1, mockProvider2],
            strategy: FirstSuccessfulStrategy()
        )

        let boolResult = try multiProvider.getBooleanEvaluation(
            key: mockKey, defaultValue: false, context: MutableContext())
        XCTAssertEqual(boolResult.value, mockProvider1Value)
        XCTAssertNil(boolResult.errorCode)
    }

    func testEvaluationWithMultipleProvidersAndFirstSuccessfulStrategy_MissingFlag() throws {
        let mockKey = "test-key"
        let mockProvider1 = MockProvider(
            initialize: { _ in },
            getBooleanEvaluation: { _, defaultValue, _ in
                return ProviderEvaluation(value: defaultValue, errorCode: .flagNotFound)
            }
        )
        let mockProvider2 = MockProvider(
            initialize: { _ in },
            getBooleanEvaluation: { _, defaultValue, _ in
                return ProviderEvaluation(value: defaultValue, errorCode: .flagNotFound)
            }
        )
        let multiProvider = MultiProvider(
            providers: [mockProvider1, mockProvider2],
            strategy: FirstSuccessfulStrategy()
        )

        do {
            _ = try multiProvider.getBooleanEvaluation(key: mockKey, defaultValue: false, context: MutableContext())
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertTrue(error as? OpenFeatureError == OpenFeatureError.flagNotFoundError(key: mockKey))
        }
    }

    func testObserveWithMultipleProviders() {
        let mockEvent1 = ProviderEvent.ready
        let mockProvider1 = MockProvider(
            getBooleanEvaluation: { _, _, _ in throw OpenFeatureError.generalError(message: "test error") },
            observe: { Just(mockEvent1).eraseToAnyPublisher() }
        )
        let mockEvent2 = ProviderEvent.contextChanged
        let mockProvider2 = MockProvider(
            getBooleanEvaluation: { _, _, _ in throw OpenFeatureError.generalError(message: "test error") },
            observe: { Just(mockEvent2).eraseToAnyPublisher() }
        )
        let multiProvider = MultiProvider(providers: [mockProvider1, mockProvider2])
        let fulfillment = XCTestExpectation(description: "Received provider events")
        let mockEvents = [mockEvent1, mockEvent2]
        var receivedEvents: [ProviderEvent] = []
        let observation =
            multiProvider
            .observe()
            .sink { event in
                if let event {
                    receivedEvents.append(event)
                }
                if receivedEvents.count == mockEvents.count {
                    fulfillment.fulfill()
                }
            }
        wait(for: [fulfillment], timeout: 2)
        observation.cancel()
        XCTAssertEqual(receivedEvents, mockEvents)
    }
}

enum MultiProviderTestHelpers {
    static func mockThrowingProvider(error: OpenFeatureError) -> MockProvider {
        return MockProvider(
            getBooleanEvaluation: { _, _, _ in throw error },
            getStringEvaluation: { _, _, _ in throw error },
            getIntegerEvaluation: { _, _, _ in throw error },
            getDoubleEvaluation: { _, _, _ in throw error },
            getObjectEvaluation: { _, _, _ in throw error }
        )
    }

    struct MockValues {
        let mockKey: String
        let mockProviderBoolValue: Bool
        let mockProviderStringValue: String
        let mockProviderIntegerValue: Int64
        let mockProviderDoubleValue: Double
        let mockProviderObjectValue: Value
    }

    static func mockTestProvider(values: MockValues) -> MockProvider {
        MockProvider(
            getBooleanEvaluation: { flag, defaultValue, _ in
                guard flag == values.mockKey else {
                    return ProviderEvaluation(value: defaultValue, errorCode: .flagNotFound)
                }
                return ProviderEvaluation(value: values.mockProviderBoolValue)
            },
            getStringEvaluation: { flag, defaultValue, _ in
                guard flag == values.mockKey else {
                    return ProviderEvaluation(value: defaultValue, errorCode: .flagNotFound)
                }
                return ProviderEvaluation(value: values.mockProviderStringValue)
            },
            getIntegerEvaluation: { flag, defaultValue, _ in
                guard flag == values.mockKey else {
                    return ProviderEvaluation(value: defaultValue, errorCode: .flagNotFound)
                }
                return ProviderEvaluation(value: values.mockProviderIntegerValue)
            },
            getDoubleEvaluation: { flag, defaultValue, _ in
                guard flag == values.mockKey else {
                    return ProviderEvaluation(value: defaultValue, errorCode: .flagNotFound)
                }
                return ProviderEvaluation(value: values.mockProviderDoubleValue)
            },
            getObjectEvaluation: { flag, defaultValue, _ in
                guard flag == values.mockKey else {
                    return ProviderEvaluation(value: defaultValue, errorCode: .flagNotFound)
                }
                return ProviderEvaluation(value: values.mockProviderObjectValue)
            }
        )
    }
}
