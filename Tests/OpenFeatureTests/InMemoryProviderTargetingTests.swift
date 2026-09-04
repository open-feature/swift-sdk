import Foundation
import OpenFeature
import XCTest

/// `InMemoryFlag.contextEvaluator` behaviour.
final class InMemoryProviderTargetingTests: XCTestCase {
    override func tearDown() {
        OpenFeatureAPI.shared.clearProvider()
        super.tearDown()
    }

    func testContextEvaluatorResolvesTargetedVariantWithTargetingMatch() throws {
        let result = try InMemoryTestFlags.readyProvider().getStringEvaluation(
            key: "context-aware",
            defaultValue: "EXTERNAL",
            context: InMemoryTestFlags.internalCustomerContext())

        XCTAssertEqual(result.value, "INTERNAL")
        XCTAssertEqual(result.variant, "internal")
        XCTAssertEqual(result.reason, "TARGETING_MATCH")
    }

    func testContextEvaluatorReturningNilFallsBackToDefaultVariant() throws {
        let result = try InMemoryTestFlags.readyProvider().getStringEvaluation(
            key: "context-aware", defaultValue: "fallback", context: MutableContext())

        XCTAssertEqual(result.value, "EXTERNAL")
        XCTAssertEqual(result.variant, "external")
        XCTAssertEqual(result.reason, "DEFAULT")
    }

    func testFlagWithoutContextEvaluatorUsesStaticReason() throws {
        let result = try InMemoryTestFlags.readyProvider().getBooleanEvaluation(
            key: "boolean-flag",
            defaultValue: false,
            context: InMemoryTestFlags.internalCustomerContext())

        XCTAssertEqual(result.reason, "STATIC")
    }

    func testContextEvaluatorRunsWithNilContext() throws {
        var sawNilContext = false
        let evaluator: InMemoryFlag.ContextEvaluator = { _, context in
            sawNilContext = context == nil
            return nil
        }
        let flag = InMemoryFlag(
            variants: ["on": .boolean(true)], defaultVariant: "on", contextEvaluator: evaluator)
        let provider = InMemoryTestFlags.readyProvider(flags: ["probe": flag])

        _ = try provider.getBooleanEvaluation(key: "probe", defaultValue: false, context: nil)

        XCTAssertTrue(sawNilContext)
    }

    func testContextEvaluatorReceivesTheFlagItIsResolving() throws {
        var seenVariantCount = 0
        let evaluator: InMemoryFlag.ContextEvaluator = { flag, _ in
            seenVariantCount = flag.variants.count
            return nil
        }
        let flag = InMemoryFlag(
            variants: ["on": .boolean(true), "off": .boolean(false)],
            defaultVariant: "on",
            contextEvaluator: evaluator)
        let provider = InMemoryTestFlags.readyProvider(flags: ["probe": flag])

        _ = try provider.getBooleanEvaluation(key: "probe", defaultValue: false, context: nil)

        XCTAssertEqual(seenVariantCount, 2)
    }

    func testContextEvaluatorResultIsTypeChecked() {
        let provider = InMemoryTestFlags.readyProvider()

        XCTAssertThrowsError(
            try provider.getBooleanEvaluation(
                key: "context-aware",
                defaultValue: false,
                context: InMemoryTestFlags.internalCustomerContext())
        ) { error in
            XCTAssertEqual((error as? OpenFeatureError)?.errorCode(), .typeMismatch)
        }
    }

    func testEvaluationUsesContextSetOnOpenFeatureAPI() async {
        await OpenFeatureAPI.shared.setProviderAndWait(
            provider: InMemoryProvider(flags: InMemoryTestFlags.all()))
        let client = OpenFeatureAPI.shared.getClient()

        XCTAssertEqual(client.getStringValue(key: "context-aware", defaultValue: "fallback"), "EXTERNAL")

        await OpenFeatureAPI.shared.setEvaluationContextAndWait(
            evaluationContext: InMemoryTestFlags.internalCustomerContext())

        XCTAssertEqual(client.getStringValue(key: "context-aware", defaultValue: "fallback"), "INTERNAL")
    }
}
