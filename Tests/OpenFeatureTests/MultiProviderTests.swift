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
        let provider1Events = PassthroughSubject<ProviderEvent?, Never>()
        let provider2Events = PassthroughSubject<ProviderEvent?, Never>()
        let mockProvider1 = MockProvider(
            getBooleanEvaluation: { _, _, _ in throw OpenFeatureError.generalError(message: "test error") },
            observe: { provider1Events.eraseToAnyPublisher() }
        )
        let mockProvider2 = MockProvider(
            getBooleanEvaluation: { _, _, _ in throw OpenFeatureError.generalError(message: "test error") },
            observe: { provider2Events.eraseToAnyPublisher() }
        )
        let multiProvider = MultiProvider(providers: [mockProvider1, mockProvider2])
        let fulfillment = XCTestExpectation(description: "Received provider events")
        let mockEvents: [ProviderEvent] = [
            .ready(nil),
            .error(ProviderEventDetails(message: "test error", errorCode: .general)),
            .configurationChanged(nil),
            .ready(nil),
        ]
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
        provider1Events.send(.ready(nil))
        provider2Events.send(.ready(nil))
        provider1Events.send(.error(ProviderEventDetails(message: "test error", errorCode: .general)))
        provider2Events.send(.configurationChanged(nil))
        provider1Events.send(.error(ProviderEventDetails(message: "test error", errorCode: .general)))
        provider1Events.send(.ready(nil))
        wait(for: [fulfillment], timeout: 2)
        observation.cancel()
        XCTAssertEqual(receivedEvents, mockEvents)
    }

    func testEvaluationRunsChildProviderHooksWithIsolatedContext() throws {
        let context = MutableContext()
        context.add(key: "shared", value: .boolean(true))

        let provider1Hook = contextMutatingHook(attributeKey: "provider1")
        let provider2Hook = contextMutatingHook(attributeKey: "provider2")

        let provider1 = MockProvider(
            getBooleanEvaluation: { _, _, _ in
                throw OpenFeatureError.generalError(message: "provider1 failure")
            }
        )
        provider1.hooks = [provider1Hook]

        let provider2 = MockProvider(
            getBooleanEvaluation: { _, _, _ in
                ProviderEvaluation(value: true)
            }
        )
        provider2.hooks = [provider2Hook]

        let multiProvider = MultiProvider(
            providers: [provider1, provider2],
            strategy: FirstSuccessfulStrategy()
        )

        let result = try multiProvider.getBooleanEvaluation(
            key: "test-key",
            defaultValue: false,
            context: context
        )

        XCTAssertTrue(result.value)
        XCTAssertEqual(provider1Hook.beforeCalled, 1)
        XCTAssertEqual(provider1Hook.errorCalled, 1)
        XCTAssertEqual(provider1Hook.afterCalled, 0)
        XCTAssertEqual(provider1Hook.finallyCalled, 1)
        XCTAssertEqual(provider2Hook.beforeCalled, 1)
        XCTAssertEqual(provider2Hook.afterCalled, 1)
        XCTAssertEqual(provider2Hook.errorCalled, 0)
        XCTAssertEqual(provider2Hook.finallyCalled, 1)
        XCTAssertEqual(provider1Hook.observedContextKeyCounts, [2])
        XCTAssertEqual(provider2Hook.observedContextKeyCounts, [2])
        XCTAssertEqual(context.keySet(), Set(["shared"]))
    }

    func testTrackForwardsOnlyToActiveProviders() throws {
        let provider1Events = PassthroughSubject<ProviderEvent?, Never>()
        let provider2Events = PassthroughSubject<ProviderEvent?, Never>()
        var trackedProviders: [String] = []

        let provider1 = MockProvider(
            observe: { provider1Events.eraseToAnyPublisher() },
            track: { _, _, _ in
                trackedProviders.append("provider1")
            }
        )
        provider1.metadata = namedProviderMetadata(name: "provider")

        let provider2 = MockProvider(
            observe: { provider2Events.eraseToAnyPublisher() },
            track: { _, _, _ in
                trackedProviders.append("provider2")
            }
        )
        provider2.metadata = namedProviderMetadata(name: "provider")

        let multiProvider = MultiProvider(providers: [provider1, provider2])

        provider1Events.send(.ready(nil))
        provider2Events.send(.error(ProviderEventDetails(message: "inactive", errorCode: .general)))

        try multiProvider.track(key: "test-track", context: nil, details: nil)

        XCTAssertEqual(trackedProviders, ["provider1"])
    }

    func testComparisonStrategyReturnsFallbackOnMismatchAndCallsCallback() throws {
        let provider1 = MockProvider(
            getBooleanEvaluation: { _, _, _ in
                ProviderEvaluation(value: true)
            }
        )
        provider1.metadata = namedProviderMetadata(name: "provider")

        let provider2 = MockProvider(
            getBooleanEvaluation: { _, _, _ in
                ProviderEvaluation(value: false)
            }
        )
        provider2.metadata = namedProviderMetadata(name: "provider")

        var mismatchResults: [ComparisonStrategyResolutionResult] = []
        let multiProvider = MultiProvider(
            providers: [provider1, provider2],
            strategy: ComparisonStrategy(
                fallbackProvider: provider2,
                onMismatch: { mismatchResults = $0 }
            )
        )

        let result = try multiProvider.getBooleanEvaluation(
            key: "test-key",
            defaultValue: false,
            context: nil
        )

        XCTAssertFalse(result.value)
        XCTAssertEqual(mismatchResults.map(\.providerName), ["provider-1", "provider-2"])
        XCTAssertEqual((mismatchResults[0].details as? ProviderEvaluation<Bool>)?.value, true)
        XCTAssertEqual((mismatchResults[1].details as? ProviderEvaluation<Bool>)?.value, false)
    }

    func testComparisonStrategyCollectsProviderErrors() {
        let provider1 = MockProvider(
            getBooleanEvaluation: { _, _, _ in
                throw OpenFeatureError.generalError(message: "provider1 failure")
            }
        )
        provider1.metadata = namedProviderMetadata(name: "provider")

        let provider2 = MockProvider(
            getBooleanEvaluation: { _, defaultValue, _ in
                ProviderEvaluation(
                    value: defaultValue,
                    errorCode: .flagNotFound,
                    errorMessage: "missing flag"
                )
            }
        )
        provider2.metadata = namedProviderMetadata(name: "provider")

        let multiProvider = MultiProvider(
            providers: [provider1, provider2],
            strategy: ComparisonStrategy(fallbackProvider: provider1)
        )

        XCTAssertThrowsError(
            try multiProvider.getBooleanEvaluation(
                key: "test-key",
                defaultValue: false,
                context: nil
            )
        ) { error in
            guard let comparisonError = error as? ComparisonStrategyError else {
                XCTFail("Unexpected error type \(error)")
                return
            }

            guard case .providerErrors(let results) = comparisonError else {
                XCTFail("Expected providerErrors")
                return
            }

            XCTAssertEqual(results.count, 2)
            XCTAssertEqual(results.map(\.providerName), ["provider-1", "provider-2"])
            XCTAssertNotNil(results[0].error)
            XCTAssertEqual(results[1].errorCode, .flagNotFound)
            XCTAssertEqual(results[1].errorMessage, "missing flag")
        }
    }

    func testMetadataDeduplicatesProviderNames() {
        let provider1 = MockProvider()
        provider1.metadata = namedProviderMetadata(name: "provider")
        let provider2 = MockProvider()
        provider2.metadata = namedProviderMetadata(name: "provider")
        let provider3 = MockProvider()
        provider3.metadata = namedProviderMetadata(name: "other")

        let multiProvider = MultiProvider(providers: [provider1, provider2, provider3])

        guard let metadata = multiProvider.metadata as? MultiProvider.MultiProviderMetadata else {
            XCTFail("Expected MultiProviderMetadata")
            return
        }

        XCTAssertEqual(metadata.name, "MultiProvider: provider-1, provider-2, other")
        XCTAssertEqual(
            Set(metadata.childProviderMetadata.keys),
            Set(["provider-1", "provider-2", "other"])
        )
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

private final class contextMutatingHook: Hook {
    typealias HookValue = Bool

    private let attributeKey: String

    var beforeCalled = 0
    var afterCalled = 0
    var errorCalled = 0
    var finallyCalled = 0
    var observedContextKeyCounts: [Int] = []

    init(attributeKey: String) {
        self.attributeKey = attributeKey
    }

    func before<HookValue>(ctx: HookContext<HookValue>, hints: [String: Any]) {
        beforeCalled += 1
        guard let mutableContext = ctx.ctx as? MutableContext else {
            return
        }

        mutableContext.add(key: attributeKey, value: .boolean(true))
        observedContextKeyCounts.append(mutableContext.keySet().count)
    }

    func after<HookValue>(ctx: HookContext<HookValue>, details: FlagEvaluationDetails<HookValue>, hints: [String: Any]) {
        afterCalled += 1
    }

    func error<HookValue>(ctx: HookContext<HookValue>, error: Error, hints: [String: Any]) {
        errorCalled += 1
    }

    func finally<HookValue>(ctx: HookContext<HookValue>, details: FlagEvaluationDetails<HookValue>, hints: [String: Any]) {
        finallyCalled += 1
    }
}

private struct namedProviderMetadata: ProviderMetadata {
    let name: String?
}
