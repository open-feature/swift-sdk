import Combine
import Logging
import XCTest

@testable import OpenFeature

// swiftlint:disable type_body_length file_length
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

    func testEvaluationWithMultipleProvidersAndFirstMatchStrategy_HandlesOpenFeatureError() throws {
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
        let defaultValue = false
        let result = try multiProvider.getBooleanEvaluation(
            key: mockKey, defaultValue: defaultValue, context: MutableContext())
        XCTAssertEqual(result.value, false)
        XCTAssertNotNil(result.errorCode)
    }

    func testEvaluationWithMultipleProvidersAndFirstMatchStrategy_Throws() throws {
        let mockKey = "test-key"
        let mockError = MockProvider.MockProviderError.message("test non-open feature error")
        let mockProvider1 = MockProvider(
            initialize: { _ in },
            getBooleanEvaluation: { _, defaultValue, _ in
                return ProviderEvaluation(value: defaultValue, errorCode: .flagNotFound)
            }
        )
        let mockProvider2 = MockProvider(
            initialize: { _ in },
            getBooleanEvaluation: { _, _, _ in
                throw mockError
            }
        )
        let multiProvider = MultiProvider(
            providers: [mockProvider1, mockProvider2],
            strategy: FirstMatchStrategy()
        )
        let defaultValue = false
        do {
            _ = try multiProvider.getBooleanEvaluation(
                key: mockKey, defaultValue: defaultValue, context: MutableContext())
            XCTFail("Expected to throw")
        } catch {
            XCTAssertTrue(error is MockProvider.MockProviderError)
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

        let defaultValue = false
        let result = try multiProvider.getBooleanEvaluation(
            key: mockKey, defaultValue: defaultValue, context: MutableContext())
        XCTAssertEqual(result.errorCode, .flagNotFound)
        XCTAssertEqual(result.value, defaultValue)
    }

    func testObserveWithMultipleProviders() {
        let mockEvent1 = ProviderEvent.ready(nil)
        let mockProvider1 = MockProvider(
            getBooleanEvaluation: { _, _, _ in throw OpenFeatureError.generalError(message: "test error") },
            observe: { Just(mockEvent1).eraseToAnyPublisher() }
        )
        let mockEvent2 = ProviderEvent.contextChanged(nil)
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
                receivedEvents.append(event)
                if receivedEvents.count == mockEvents.count {
                    fulfillment.fulfill()
                }
            }
        wait(for: [fulfillment], timeout: 2)
        observation.cancel()
        XCTAssertEqual(receivedEvents.count, mockEvents.count)
        XCTAssertTrue(receivedEvents.contains(mockEvent1))
        XCTAssertTrue(receivedEvents.contains(mockEvent2))
    }

    func testTrackWithMultipleProviders_CallsAllProviders() throws {
        let provider1 = "Provider1"
        let provider2 = "Provider2"
        let provider3 = "Provider3"

        var calledProviders: [String] = []
        let mockProvider1 = MultiProviderTestHelpers.mockTrackingProvider(name: provider1) { _, _, _ in
            calledProviders.append(provider1)
        }

        let mockProvider2 = MultiProviderTestHelpers.mockTrackingProvider(name: provider2) { _, _, _ in
            calledProviders.append(provider2)
        }

        let mockProvider3 = MultiProviderTestHelpers.mockTrackingProvider(name: provider3) { _, _, _ in
            calledProviders.append(provider3)
        }

        let multiProvider = MultiProvider(providers: [mockProvider1, mockProvider2, mockProvider3])

        try multiProvider.track(
            key: "test-event",
            context: nil,
            details: nil
        )

        let expectedProviders = [provider1, provider2, provider3]

        XCTAssertEqual(calledProviders, expectedProviders, "Providers called do not match expected providers")
    }

    func testTrackWithMultipleProviders_LogsErrorsAndContinues() throws {
        var calledProviders: [String] = []
        let logHandler = CapturingLogHandler()
        let logger = Logger(label: "test.track") { _ in logHandler }

        let mockProvider1 = MultiProviderTestHelpers.mockTrackingProvider(name: "AnalyticsProvider") { _, _, _ in
            calledProviders.append("AnalyticsProvider")
            throw OpenFeatureError.generalError(message: "Analytics service unavailable")
        }

        let mockProvider2 = MultiProviderTestHelpers.mockTrackingProvider(name: "MetricsProvider") { _, _, _ in
            calledProviders.append("MetricsProvider")
            throw OpenFeatureError.generalError(message: "Metrics endpoint failed")
        }

        let mockProvider3 = MultiProviderTestHelpers.mockTrackingProvider(name: "SuccessfulProvider") { _, _, _ in
            calledProviders.append("SuccessfulProvider")
        }

        let multiProvider = MultiProvider(
            providers: [mockProvider1, mockProvider2, mockProvider3],
            logger: logger
        )

        try multiProvider.track(
            key: "test-event",
            context: nil,
            details: nil
        )

        XCTAssertEqual(
            calledProviders,
            ["AnalyticsProvider", "MetricsProvider", "SuccessfulProvider"],
            "All providers should be called even if some throw errors"
        )

        let errorMessages = logHandler.messages.filter { $0.level == .error }.map { $0.message }
        XCTAssertEqual(errorMessages.count, 2, "Should log exactly two errors")
        XCTAssertTrue(errorMessages[0].contains("AnalyticsProvider"))
        XCTAssertTrue(errorMessages[0].contains("Analytics service unavailable"))
        XCTAssertTrue(errorMessages[1].contains("MetricsProvider"))
        XCTAssertTrue(errorMessages[1].contains("Metrics endpoint failed"))
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

    static func mockTrackingProvider(
        name: String,
        track: @escaping (String, EvaluationContext?, TrackingEventDetails?) throws -> Void
    ) -> MockProvider {
        let provider = MockProvider(track: track)
        provider.metadata = MockProvider.MockProviderMetadata(name: name)
        return provider
    }
}

class CapturingLogHandler: LogHandler {
    struct LogEntry {
        let level: Logger.Level
        let message: String
    }

    var messages: [LogEntry] = []
    var metadata: Logger.Metadata = [:]
    var logLevel: Logger.Level = .trace

    subscript(metadataKey key: String) -> Logger.Metadata.Value? {
        get { metadata[key] }
        set { metadata[key] = newValue }
    }

    // swiftlint:disable:next function_parameter_count
    func log(
        level: Logger.Level,
        message: Logger.Message,
        metadata: Logger.Metadata?,
        source: String,
        file: String,
        function: String,
        line: UInt
    ) {
        messages.append(LogEntry(level: level, message: message.description))
    }
}
// swiftlint:enable type_body_length file_length
