import Foundation
import XCTest

@testable import OpenFeature

/// `LoggingHook` per the logging hook of Appendix A: what each stage logs, at which level, and how values and the
/// evaluation context are written.
final class LoggingHookTests: XCTestCase {
    override func setUp() async throws {
        try await super.setUp()
        await OpenFeatureAPI.shared.shutdownAndWait()
        await OpenFeatureAPI.shared.setEvaluationContextAndWait(
            evaluationContext: ImmutableContext(
                targetingKey: "user-1",
                structure: ImmutableStructure(attributes: [
                    "plan": .string("pro"),
                    "beta": .boolean(true),
                    "address": .structure(["city": .string("Oslo")]),
                ])))
    }

    override func tearDown() async throws {
        // Leave no provider or evaluation context behind for other test cases.
        await OpenFeatureAPI.shared.shutdownAndWait()
        try await super.tearDown()
    }

    // MARK: - Stages

    func testSuccessfulEvaluationLogsBeforeAndAfterAtDebugLevel() async {
        await OpenFeatureAPI.shared.setProviderAndWait(provider: InMemoryProvider(flags: InMemoryTestFlags.all()))
        let client = OpenFeatureAPI.shared.getClient(name: "checkout", version: nil)
        let logger = CapturingLogger()

        _ = client.getValue(
            key: "boolean-flag",
            defaultValue: false,
            options: FlagEvaluationOptions(hooks: [LoggingHook(logger: logger)]))

        XCTAssertEqual(
            logger.entries,
            [
                CapturingLogger.Entry(
                    level: .debug,
                    message: #"stage="before" domain="checkout" provider_name="InMemoryProvider" "#
                        + #"flag_key="boolean-flag" default_value=false"#),
                CapturingLogger.Entry(
                    level: .debug,
                    message: #"stage="after" domain="checkout" provider_name="InMemoryProvider" "#
                        + #"flag_key="boolean-flag" default_value=false reason="STATIC" variant="on" value=true"#),
            ])
    }

    func testFailedEvaluationLogsErrorCodeAndMessageAtErrorLevel() async {
        await OpenFeatureAPI.shared.setProviderAndWait(provider: InMemoryProvider(flags: InMemoryTestFlags.all()))
        let client = OpenFeatureAPI.shared.getClient(name: "checkout", version: nil)
        let logger = CapturingLogger()

        _ = client.getValue(
            key: "missing",
            defaultValue: "fallback",
            options: FlagEvaluationOptions(hooks: [LoggingHook(logger: logger)]))

        let before =
            #"stage="before" domain="checkout" provider_name="InMemoryProvider" flag_key="missing" "#
            + #"default_value="fallback""#
        let error =
            #"stage="error" domain="checkout" provider_name="InMemoryProvider" flag_key="missing" "#
            + #"default_value="fallback" error_code="FLAG_NOT_FOUND" "#
            + #"error_message="Could not find flag for key: missing""#
        XCTAssertEqual(logger.messages(at: .debug), [before])
        XCTAssertEqual(logger.messages(at: .error), [error])
    }

    func testFinallyStageLogsNothing() {
        let logger = CapturingLogger()
        let hook = LoggingHook(logger: logger, includeEvaluationContext: true)

        hook.finally(
            ctx: makeContext(defaultValue: false),
            details: FlagEvaluationDetails(flagKey: "flag", value: true),
            hints: [:])

        XCTAssertTrue(logger.entries.isEmpty)
    }

    func testUnknownErrorIsLoggedAsGeneral() {
        struct CustomError: Error, CustomStringConvertible {
            var description: String { "boom" }
        }
        let logger = CapturingLogger()

        LoggingHook(logger: logger).error(ctx: makeContext(defaultValue: false), error: CustomError(), hints: [:])

        XCTAssertEqual(
            logger.messages(at: .error),
            [#"stage="error" flag_key="flag" default_value=false error_code="GENERAL" error_message="boom""#])
    }

    func testDataTheEvaluationDoesNotHaveIsLeftOut() async {
        let client = OpenFeatureAPI.shared.getClient()
        let logger = CapturingLogger()

        _ = client.getValue(
            key: "flag", defaultValue: false, options: FlagEvaluationOptions(hooks: [LoggingHook(logger: logger)]))

        // No client name, no provider name, and no reason or variant on the error path.
        XCTAssertEqual(
            logger.entries,
            [
                CapturingLogger.Entry(level: .debug, message: #"stage="before" flag_key="flag" default_value=false"#),
                CapturingLogger.Entry(
                    level: .error,
                    message: #"stage="error" flag_key="flag" default_value=false error_code="PROVIDER_NOT_READY" "#
                        + #"error_message="The value was resolved before the provider was ready""#),
            ])
    }

    func testAfterStageLeavesOutMissingReasonAndVariant() {
        let logger = CapturingLogger()

        LoggingHook(logger: logger).after(
            ctx: makeContext(defaultValue: false),
            details: FlagEvaluationDetails(flagKey: "flag", value: true),
            hints: [:])

        XCTAssertEqual(
            logger.messages(at: .debug), [#"stage="after" flag_key="flag" default_value=false value=true"#])
    }

    // MARK: - Evaluation context

    func testEvaluationContextIsNotLoggedByDefault() async {
        await OpenFeatureAPI.shared.setProviderAndWait(provider: InMemoryProvider(flags: InMemoryTestFlags.all()))
        let client = OpenFeatureAPI.shared.getClient()
        let logger = CapturingLogger()
        let options = FlagEvaluationOptions(hooks: [LoggingHook(logger: logger)])

        _ = client.getValue(key: "boolean-flag", defaultValue: false, options: options)
        _ = client.getValue(key: "missing", defaultValue: false, options: options)

        XCTAssertEqual(logger.entries.count, 4)
        XCTAssertTrue(logger.entries.allSatisfy { !$0.message.contains("evaluation_context") })
        XCTAssertTrue(logger.entries.allSatisfy { !$0.message.contains("user-1") })
    }

    func testEvaluationContextIsLoggedAsJsonInEveryStageWhenEnabled() async {
        await OpenFeatureAPI.shared.setProviderAndWait(provider: InMemoryProvider(flags: InMemoryTestFlags.all()))
        let client = OpenFeatureAPI.shared.getClient()
        let logger = CapturingLogger()
        let options = FlagEvaluationOptions(hooks: [LoggingHook(logger: logger, includeEvaluationContext: true)])

        _ = client.getValue(key: "boolean-flag", defaultValue: false, options: options)
        _ = client.getValue(key: "missing", defaultValue: false, options: options)

        let context =
            #"evaluation_context={"attributes":{"address":{"city":"Oslo"},"beta":true,"plan":"pro"},"#
            + #""targetingKey":"user-1"}"#
        XCTAssertEqual(logger.entries.count, 4)
        XCTAssertEqual(
            logger.entries.first?.message,
            #"stage="before" provider_name="InMemoryProvider" flag_key="boolean-flag" default_value=false "# + context)
        XCTAssertTrue(logger.entries.allSatisfy { $0.message.contains(context) })
    }

    func testMissingEvaluationContextIsLeftOut() {
        let logger = CapturingLogger()

        LoggingHook(logger: logger, includeEvaluationContext: true).before(
            ctx: makeContext(defaultValue: false), hints: [:])

        XCTAssertEqual(logger.messages(at: .debug), [#"stage="before" flag_key="flag" default_value=false"#])
    }

    // MARK: - Values

    func testRunsForEveryFlagValueType() async {
        await OpenFeatureAPI.shared.setProviderAndWait(provider: InMemoryProvider(flags: InMemoryTestFlags.all()))
        let client = OpenFeatureAPI.shared.getClient()
        let logger = CapturingLogger()
        client.addHooks(LoggingHook(logger: logger))

        _ = client.getValue(key: "boolean-flag", defaultValue: false)
        _ = client.getValue(key: "string-flag", defaultValue: "default")
        _ = client.getValue(key: "integer-flag", defaultValue: Int64(0))
        _ = client.getValue(key: "float-flag", defaultValue: 0.0)
        _ = client.getValue(key: "object-flag", defaultValue: Value.null)
        _ = client.getValue(key: "list-flag", defaultValue: Value.list([]))

        XCTAssertEqual(
            logger.messages(at: .debug).filter { $0.hasPrefix(#"stage="after""#) },
            [
                #"stage="after" provider_name="InMemoryProvider" flag_key="boolean-flag" default_value=false "#
                    + #"reason="STATIC" variant="on" value=true"#,
                #"stage="after" provider_name="InMemoryProvider" flag_key="string-flag" default_value="default" "#
                    + #"reason="STATIC" variant="greeting" value="hi""#,
                #"stage="after" provider_name="InMemoryProvider" flag_key="integer-flag" default_value=0 "#
                    + #"reason="STATIC" variant="ten" value=10"#,
                #"stage="after" provider_name="InMemoryProvider" flag_key="float-flag" default_value=0.0 "#
                    + #"reason="STATIC" variant="half" value=0.5"#,
                #"stage="after" provider_name="InMemoryProvider" flag_key="object-flag" default_value=null "#
                    + #"reason="STATIC" variant="template" "#
                    + #"value={"imagesPerPage":100,"showImages":true,"title":"Check out these pics!"}"#,
                #"stage="after" provider_name="InMemoryProvider" flag_key="list-flag" default_value=[] "#
                    + #"reason="STATIC" variant="items" value=["a",1,true]"#,
            ])
    }

    func testStringsAreEscaped() {
        let logger = CapturingLogger()

        LoggingHook(logger: logger).before(
            ctx: makeContext(flagKey: "say \"hi\"", defaultValue: "a\\b\nc https://example.com"), hints: [:])

        XCTAssertEqual(
            logger.messages(at: .debug),
            [#"stage="before" flag_key="say \"hi\"" default_value="a\\b\nc https://example.com""#])
    }

    func testDatesAndNonFiniteDoublesAreReadable() {
        let logger = CapturingLogger()
        let value: Value = .structure([
            "date": .date(Date(timeIntervalSince1970: 0)),
            "nan": .double(.nan),
            "infinity": .double(.infinity),
        ])

        LoggingHook(logger: logger).before(ctx: makeContext(defaultValue: value), hints: [:])

        let expected =
            #"stage="before" flag_key="flag" "#
            + #"default_value={"date":"1970-01-01T00:00:00.000Z","infinity":inf,"nan":nan}"#
        XCTAssertEqual(logger.messages(at: .debug), [expected])
    }

    // MARK: - Helpers

    private func makeContext<T>(flagKey: String = "flag", defaultValue: T) -> HookContext<T> {
        HookContext(
            flagKey: flagKey,
            type: .boolean,
            defaultValue: defaultValue,
            ctx: nil,
            clientMetadata: nil,
            providerMetadata: nil)
    }
}
