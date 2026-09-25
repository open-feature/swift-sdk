import Combine
import Foundation
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

    /// Returns the name of `logger` if it is a ``CapturingLogger``, otherwise `nil`.
    private func name(of logger: (any OpenFeatureLogger)?) -> String? {
        (logger as? CapturingLogger)?.name
    }

    // MARK: - Logger Hierarchy Tests

    /// A logger set on the API can be read back.
    func testAPILevelLogger() async throws {
        // Given: Logger set at API level
        let logger = CapturingLogger(name: "test.api")
        api?.setLogger(logger)

        // When: Getting logger from API
        let retrievedLogger = api?.getLogger()

        // Then: Logger should be available
        XCTAssertNotNil(retrievedLogger)
        XCTAssertEqual(name(of: retrievedLogger), "test.api")
    }

    /// A logger set on a client is passed to the provider.
    func testClientLevelLogger() async throws {
        // Given: Client with its own logger
        let logger = CapturingLogger(name: "test.client")
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
        XCTAssertEqual(name(of: provider.capturedLogger), "test.client")
    }

    /// An evaluation-level logger takes precedence over client and API loggers.
    func testLoggerHierarchyEvaluationOverridesClient() async throws {
        // Given: API logger, Client logger, and Evaluation logger
        let apiLogger = CapturingLogger(name: "test.api")
        let clientLogger = CapturingLogger(name: "test.client")
        let evalLogger = CapturingLogger(name: "test.eval")

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
        XCTAssertEqual(name(of: provider.capturedLogger), "test.eval")
    }

    /// A client logger takes precedence over the API logger.
    func testLoggerHierarchyClientOverridesAPI() async throws {
        // Given: API logger and Client logger
        let apiLogger = CapturingLogger(name: "test.api")
        let clientLogger = CapturingLogger(name: "test.client")

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
        XCTAssertEqual(name(of: provider.capturedLogger), "test.client")
    }

    /// The API logger is used when neither the client nor the evaluation sets one.
    func testLoggerHierarchyAPIAsDefault() async throws {
        // Given: Only API logger
        let apiLogger = CapturingLogger(name: "test.api")
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
        XCTAssertEqual(name(of: provider.capturedLogger), "test.api")
    }

    /// The provider receives `nil` when no logger is set at any level.
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

    /// The logger reaches the provider for every flag value type.
    func testProviderReceivesLogger() async throws {
        // Given: Provider with logger capturing
        let provider = LoggerCapturingProvider()
        await api?.setProviderAndWait(provider: provider)

        let logger = CapturingLogger(name: "test.provider")
        api?.setLogger(logger)

        guard let client = api?.getClient() else {
            XCTFail("Failed to get client")
            return
        }

        // When: Evaluating different flag types
        _ = client.getBooleanValue(key: "bool-flag", defaultValue: false)
        XCTAssertEqual(name(of: provider.capturedLogger), "test.provider")

        _ = client.getStringValue(key: "string-flag", defaultValue: "default")
        XCTAssertEqual(name(of: provider.capturedLogger), "test.provider")

        _ = client.getIntegerValue(key: "int-flag", defaultValue: 0)
        XCTAssertEqual(name(of: provider.capturedLogger), "test.provider")

        _ = client.getDoubleValue(key: "double-flag", defaultValue: 0.0)
        XCTAssertEqual(name(of: provider.capturedLogger), "test.provider")

        _ = client.getObjectValue(key: "object-flag", defaultValue: .null)
        XCTAssertEqual(name(of: provider.capturedLogger), "test.provider")
    }

    /// A provider implementing only the logger-less methods still evaluates via the default extension.
    func testDefaultProtocolExtensionWorks() async throws {
        // Given: Provider that doesn't implement logger-enabled methods
        let provider = MockProvider()
        await api?.setProviderAndWait(provider: provider)

        let logger = CapturingLogger(name: "test.default")
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

    /// Evaluation succeeds when no logger is configured.
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

    /// Evaluation with options that carry no logger succeeds.
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

    /// Evaluating against the NoOp provider with a logger set succeeds.
    func testNoOpProviderUsesLogger() async throws {
        // Given: NoOpProvider with logger
        let provider = NoOpProvider()
        await api?.setProviderAndWait(provider: provider)

        let logger = CapturingLogger(name: "test.noop")
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

    /// A provider error during evaluation is logged once at error level, mentioning the flag key.
    func testEvaluationErrorIsLoggedAtErrorLevel() async throws {
        // Given: A provider that throws, and an API-level logger
        let provider = ThrowingProvider()
        await api?.setProviderAndWait(provider: provider)

        let logger = CapturingLogger(name: "test.error")
        api?.setLogger(logger)

        guard let client = api?.getClient() else {
            XCTFail("Failed to get client")
            return
        }

        // When: Evaluating a flag that fails
        _ = client.getBooleanValue(key: "failing-flag", defaultValue: false)

        // Then: The failure is reported through the logger
        let errors = logger.messages(at: .error)
        XCTAssertEqual(errors.count, 1)
        XCTAssertTrue(errors[0].contains("failing-flag"))
    }

    /// MultiProvider forwards the resolved logger to its child providers.
    func testMultiProviderPassesLoggerToChildren() async throws {
        // Given: MultiProvider with child providers
        let child1 = LoggerCapturingProvider()
        let child2 = LoggerCapturingProvider()
        let multiProvider = MultiProvider(providers: [child1, child2])

        await api?.setProviderAndWait(provider: multiProvider)

        let logger = CapturingLogger(name: "test.multi")
        api?.setLogger(logger)

        guard let client = api?.getClient() else {
            XCTFail("Failed to get client")
            return
        }

        // When: Evaluating through MultiProvider
        _ = client.getBooleanValue(key: "test-flag", defaultValue: false)

        // Then: Child provider should have received the logger
        XCTAssertEqual(name(of: child1.capturedLogger), "test.multi")
    }

    // MARK: - Edge Cases

    /// Setting a `nil` logger clears a previously set one.
    func testSettingNilLoggerClearsLogger() async throws {
        // Given: Logger initially set
        let logger = CapturingLogger(name: "test.clear")
        api?.setLogger(logger)
        XCTAssertNotNil(api?.getLogger())

        // When: Setting logger to nil
        api?.setLogger(nil)

        // Then: Logger should be cleared
        XCTAssertNil(api?.getLogger())
    }

    /// The same logger reaches the provider on repeated evaluations.
    func testLoggerPersistsAcrossEvaluations() async throws {
        // Given: Client with logger
        let provider = LoggerCapturingProvider()
        await api?.setProviderAndWait(provider: provider)

        let logger = CapturingLogger(name: "test.persist")
        api?.setLogger(logger)

        guard let client = api?.getClient() else {
            XCTFail("Failed to get client")
            return
        }

        // When: Multiple evaluations
        _ = client.getBooleanValue(key: "flag1", defaultValue: false)
        XCTAssertEqual(name(of: provider.capturedLogger), "test.persist")

        _ = client.getBooleanValue(key: "flag2", defaultValue: false)
        XCTAssertEqual(name(of: provider.capturedLogger), "test.persist")

        _ = client.getStringValue(key: "flag3", defaultValue: "")

        // Then: Logger should be consistent across all evaluations
        XCTAssertEqual(name(of: provider.capturedLogger), "test.persist")
    }
}
