import Combine
import Foundation
import Logging
import XCTest

@testable import OpenFeature

final class LoggerTests: XCTestCase {
    var api: OpenFeatureAPI?

    override func setUp() async throws {
        try await super.setUp()
        api = OpenFeatureAPI()
    }

    override func tearDown() async throws {
        await api?.clearProviderAndWait()
        api = nil
        try await super.tearDown()
    }

    // MARK: - Logger Hierarchy Tests

    func testAPILevelLogger() async throws {
        // Given: Logger set at API level
        let logger = Logger(label: "test.api")
        api?.setLogger(logger)

        // When: Getting logger from API
        let retrievedLogger = api?.getLogger()

        // Then: Logger should be available
        XCTAssertNotNil(retrievedLogger)
        XCTAssertEqual(retrievedLogger?.label, "test.api")
    }

    func testClientLevelLogger() async throws {
        // Given: Client with its own logger
        let logger = Logger(label: "test.client")
        let provider = LoggerCapturingProvider()
        await api?.setProviderAndWait(provider: provider)

        guard let client = api?.getClient() else {
            XCTFail("Failed to get client")
            return
        }

        // When: Setting logger on client
        client.setLogger(logger)

        // Then: Evaluations should use the client's logger
        _ = client.getBooleanValue(key: "test-flag", defaultValue: false)
        XCTAssertEqual(provider.capturedLogger?.label, "test.client")
    }

    func testLoggerHierarchyEvaluationOverridesClient() async throws {
        // Given: API logger, Client logger, and Evaluation logger
        let apiLogger = Logger(label: "test.api")
        let clientLogger = Logger(label: "test.client")
        let evalLogger = Logger(label: "test.eval")

        api?.setLogger(apiLogger)

        let provider = LoggerCapturingProvider()
        await api?.setProviderAndWait(provider: provider)

        guard let client = api?.getClient() as? OpenFeatureClient else {
            XCTFail("Failed to get OpenFeatureClient")
            return
        }
        client.setLogger(clientLogger)

        // When: Evaluating with evaluation-level logger
        let options = FlagEvaluationOptions(logger: evalLogger)
        _ = client.getBooleanValue(key: "test-flag", defaultValue: false, options: options)

        // Then: Provider should receive evaluation logger (highest priority)
        XCTAssertEqual(provider.capturedLogger?.label, "test.eval")
    }

    func testLoggerHierarchyClientOverridesAPI() async throws {
        // Given: API logger and Client logger
        let apiLogger = Logger(label: "test.api")
        let clientLogger = Logger(label: "test.client")

        api?.setLogger(apiLogger)

        let provider = LoggerCapturingProvider()
        await api?.setProviderAndWait(provider: provider)

        guard let client = api?.getClient() as? OpenFeatureClient else {
            XCTFail("Failed to get OpenFeatureClient")
            return
        }
        client.setLogger(clientLogger)

        // When: Evaluating without evaluation-level logger
        _ = client.getBooleanValue(key: "test-flag", defaultValue: false)

        // Then: Provider should receive client logger (overrides API)
        XCTAssertEqual(provider.capturedLogger?.label, "test.client")
    }

    func testLoggerHierarchyAPIAsDefault() async throws {
        // Given: Only API logger
        let apiLogger = Logger(label: "test.api")
        api?.setLogger(apiLogger)

        let provider = LoggerCapturingProvider()
        await api?.setProviderAndWait(provider: provider)

        guard let client = api?.getClient() else {
            XCTFail("Failed to get client")
            return
        }

        // When: Evaluating without client or evaluation logger
        _ = client.getBooleanValue(key: "test-flag", defaultValue: false)

        // Then: Provider should receive API logger
        XCTAssertEqual(provider.capturedLogger?.label, "test.api")
    }

    func testNoLoggerProvided() async throws {
        // Given: No loggers set at any level
        let provider = LoggerCapturingProvider()
        await api?.setProviderAndWait(provider: provider)

        guard let client = api?.getClient() else {
            XCTFail("Failed to get client")
            return
        }

        // When: Evaluating without any logger
        _ = client.getBooleanValue(key: "test-flag", defaultValue: false)

        // Then: Provider should receive nil logger
        XCTAssertNil(provider.capturedLogger)
    }

    // MARK: - Provider Integration Tests

    func testProviderReceivesLogger() async throws {
        // Given: Provider with logger capturing
        let provider = LoggerCapturingProvider()
        await api?.setProviderAndWait(provider: provider)

        let logger = Logger(label: "test.provider")
        api?.setLogger(logger)

        guard let client = api?.getClient() else {
            XCTFail("Failed to get client")
            return
        }

        // When: Evaluating different flag types
        _ = client.getBooleanValue(key: "bool-flag", defaultValue: false)
        XCTAssertEqual(provider.capturedLogger?.label, "test.provider")

        _ = client.getStringValue(key: "string-flag", defaultValue: "default")
        XCTAssertEqual(provider.capturedLogger?.label, "test.provider")

        _ = client.getIntegerValue(key: "int-flag", defaultValue: 0)
        XCTAssertEqual(provider.capturedLogger?.label, "test.provider")

        _ = client.getDoubleValue(key: "double-flag", defaultValue: 0.0)
        XCTAssertEqual(provider.capturedLogger?.label, "test.provider")

        _ = client.getObjectValue(key: "object-flag", defaultValue: .null)
        XCTAssertEqual(provider.capturedLogger?.label, "test.provider")
    }

    func testDefaultProtocolExtensionWorks() async throws {
        // Given: Provider that doesn't implement logger-enabled methods
        let provider = MockProvider()
        await api?.setProviderAndWait(provider: provider)

        let logger = Logger(label: "test.default")
        api?.setLogger(logger)

        guard let client = api?.getClient() else {
            XCTFail("Failed to get client")
            return
        }

        // When: Evaluating flags (should use default implementation)
        let result = client.getBooleanValue(key: "test-flag", defaultValue: true)

        // Then: Should work without errors
        XCTAssertEqual(result, true)
    }

    // MARK: - Backwards Compatibility Tests

    func testEvaluationWithoutLoggerStillWorks() async throws {
        // Given: Provider and client setup without any loggers
        let provider = DoSomethingProvider()
        await api?.setProviderAndWait(provider: provider)

        guard let client = api?.getClient() else {
            XCTFail("Failed to get client")
            return
        }

        // When: Evaluating normally
        let boolResult = client.getBooleanValue(key: "test", defaultValue: false)
        let stringResult = client.getStringValue(key: "test", defaultValue: "hello")
        let intResult = client.getIntegerValue(key: "test", defaultValue: 5)
        let doubleResult = client.getDoubleValue(key: "test", defaultValue: 5.0)

        // Then: All evaluations should work
        XCTAssertTrue(boolResult)  // DoSomethingProvider inverts
        XCTAssertEqual(stringResult, "olleh")  // DoSomethingProvider reverses
        XCTAssertEqual(intResult, 500)  // DoSomethingProvider multiplies by 100
        XCTAssertEqual(doubleResult, 500.0)
    }

    func testFlagEvaluationOptionsWithoutLogger() async throws {
        // Given: Options without logger
        let provider = DoSomethingProvider()
        await api?.setProviderAndWait(provider: provider)

        guard let client = api?.getClient() else {
            XCTFail("Failed to get client")
            return
        }
        let options = FlagEvaluationOptions(hooks: [])

        // When: Evaluating with options but no logger
        let result = client.getBooleanValue(key: "test", defaultValue: false, options: options)

        // Then: Should work normally
        XCTAssertTrue(result)
    }

    // MARK: - Logger Usage Tests

    func testNoOpProviderUsesLogger() async throws {
        // Given: NoOpProvider with logger
        let provider = NoOpProvider()
        await api?.setProviderAndWait(provider: provider)

        let logger = Logger(label: "test.noop")
        api?.setLogger(logger)

        guard let client = api?.getClient() else {
            XCTFail("Failed to get client")
            return
        }

        // When: Evaluating (NoOpProvider logs at debug level)
        _ = client.getBooleanValue(key: "test-flag", defaultValue: false)

        // Then: Evaluation should succeed (logger usage is internal)
        // This test verifies that having a logger doesn't break functionality
        XCTAssertTrue(true)
    }

    func testMultiProviderPassesLoggerToChildren() async throws {
        // Given: MultiProvider with child providers
        let child1 = LoggerCapturingProvider()
        let child2 = LoggerCapturingProvider()
        let multiProvider = MultiProvider(providers: [child1, child2])

        await api?.setProviderAndWait(provider: multiProvider)

        let logger = Logger(label: "test.multi")
        api?.setLogger(logger)

        guard let client = api?.getClient() else {
            XCTFail("Failed to get client")
            return
        }

        // When: Evaluating through MultiProvider
        _ = client.getBooleanValue(key: "test-flag", defaultValue: false)

        // Then: Child provider should have received the logger
        XCTAssertEqual(child1.capturedLogger?.label, "test.multi")
    }

    // MARK: - Edge Cases

    func testSettingNilLoggerClearsLogger() async throws {
        // Given: Logger initially set
        let logger = Logger(label: "test.clear")
        api?.setLogger(logger)
        XCTAssertNotNil(api?.getLogger())

        // When: Setting logger to nil
        api?.setLogger(nil)

        // Then: Logger should be cleared
        XCTAssertNil(api?.getLogger())
    }

    func testLoggerPersistsAcrossEvaluations() async throws {
        // Given: Client with logger
        let provider = LoggerCapturingProvider()
        await api?.setProviderAndWait(provider: provider)

        let logger = Logger(label: "test.persist")
        api?.setLogger(logger)

        guard let client = api?.getClient() else {
            XCTFail("Failed to get client")
            return
        }

        // When: Multiple evaluations
        _ = client.getBooleanValue(key: "flag1", defaultValue: false)
        XCTAssertEqual(provider.capturedLogger?.label, "test.persist")

        _ = client.getBooleanValue(key: "flag2", defaultValue: false)
        XCTAssertEqual(provider.capturedLogger?.label, "test.persist")

        _ = client.getStringValue(key: "flag3", defaultValue: "")

        // Then: Logger should be consistent across all evaluations
        XCTAssertEqual(provider.capturedLogger?.label, "test.persist")
    }
}

// MARK: - Test Helpers

/// A provider that captures the logger it receives for testing
class LoggerCapturingProvider: FeatureProvider {
    var hooks: [any Hook] = []
    var metadata: ProviderMetadata = TestMetadata()
    var capturedLogger: Logger?
    private let eventHandler = EventHandler()

    func initialize(initialContext: EvaluationContext?) async throws {}
    func onContextSet(oldContext: EvaluationContext?, newContext: EvaluationContext) async throws {}

    func getBooleanEvaluation(key: String, defaultValue: Bool, context: EvaluationContext?) throws
        -> ProviderEvaluation<Bool> { ProviderEvaluation(value: defaultValue) }

    func getStringEvaluation(key: String, defaultValue: String, context: EvaluationContext?) throws
        -> ProviderEvaluation<String> { ProviderEvaluation(value: defaultValue) }

    func getIntegerEvaluation(key: String, defaultValue: Int64, context: EvaluationContext?) throws
        -> ProviderEvaluation<Int64> { ProviderEvaluation(value: defaultValue) }

    func getDoubleEvaluation(key: String, defaultValue: Double, context: EvaluationContext?) throws
        -> ProviderEvaluation<Double> { ProviderEvaluation(value: defaultValue) }

    func getObjectEvaluation(key: String, defaultValue: Value, context: EvaluationContext?) throws
        -> ProviderEvaluation<Value> { ProviderEvaluation(value: defaultValue) }

    // Logger-enabled overrides that capture the logger
    func getBooleanEvaluation(key: String, defaultValue: Bool, context: EvaluationContext?, logger: Logger?) throws
        -> ProviderEvaluation<Bool> {
        capturedLogger = logger; return try getBooleanEvaluation(key: key, defaultValue: defaultValue, context: context)
    }

    func getStringEvaluation(key: String, defaultValue: String, context: EvaluationContext?, logger: Logger?) throws
        -> ProviderEvaluation<String> {
        capturedLogger = logger; return try getStringEvaluation(key: key, defaultValue: defaultValue, context: context)
    }

    func getIntegerEvaluation(key: String, defaultValue: Int64, context: EvaluationContext?, logger: Logger?) throws
        -> ProviderEvaluation<Int64> {
        capturedLogger = logger; return try getIntegerEvaluation(key: key, defaultValue: defaultValue, context: context)
    }

    func getDoubleEvaluation(key: String, defaultValue: Double, context: EvaluationContext?, logger: Logger?) throws
        -> ProviderEvaluation<Double> {
        capturedLogger = logger; return try getDoubleEvaluation(key: key, defaultValue: defaultValue, context: context)
    }

    func getObjectEvaluation(key: String, defaultValue: Value, context: EvaluationContext?, logger: Logger?) throws
        -> ProviderEvaluation<Value> {
        capturedLogger = logger; return try getObjectEvaluation(key: key, defaultValue: defaultValue, context: context)
    }

    func observe() -> AnyPublisher<ProviderEvent?, Never> { eventHandler.observe() }
    struct TestMetadata: ProviderMetadata { var name: String? = "LoggerCapturingProvider" }
}
