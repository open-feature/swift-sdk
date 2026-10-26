import Combine
import Foundation
import XCTest

@testable import OpenFeature

/// `OpenFeatureAPI.shutdown()` / `shutdownAndWait()` (specification 1.6.1, 1.6.2): the provider is shut down and
/// the API's state is reset, after which the API can be used again.
final class ShutdownSpecTests: XCTestCase {
    override func setUp() async throws {
        try await super.setUp()
        await OpenFeatureAPI.shared.shutdownAndWait()
    }

    // MARK: - Provider shutdown

    func testShutdownCallsTheProviderShutdownAndRemovesIt() async {
        let provider = ShutdownSpyProvider()
        await OpenFeatureAPI.shared.setProviderAndWait(provider: provider)
        XCTAssertEqual(OpenFeatureAPI.shared.getProviderStatus(), .ready)

        await OpenFeatureAPI.shared.shutdownAndWait()

        XCTAssertEqual(provider.shutdownCalls, 1)
        XCTAssertNil(OpenFeatureAPI.shared.getProvider())
        XCTAssertEqual(OpenFeatureAPI.shared.getProviderStatus(), .notReady)
        XCTAssertEqual(provider.status, .notReady)
    }

    func testShutdownAndWaitReturnsOnlyAfterTheProviderFinishes() {
        let provider = ShutdownSpyProvider(holdShutdown: true)
        installProviderAndWaitForReady(provider)
        let returnedTooEarly = expectation(description: "shutdownAndWait returned before the provider finished")
        returnedTooEarly.isInverted = true
        let finished = expectation(description: "shutdownAndWait returned")

        Task {
            await OpenFeatureAPI.shared.shutdownAndWait()
            returnedTooEarly.fulfill()
            finished.fulfill()
        }

        wait(for: [returnedTooEarly], timeout: 0.5)
        XCTAssertEqual(provider.shutdownCalls, 1)
        provider.completeShutdown()
        wait(for: [finished], timeout: 5)
    }

    func testFireAndForgetShutdownShutsTheProviderDownInTheBackground() {
        let shutDown = expectation(description: "shutdown called")
        let provider = ShutdownSpyProvider { call in
            if call == "shutdown:spy" {
                shutDown.fulfill()
            }
        }
        installProviderAndWaitForReady(provider)

        OpenFeatureAPI.shared.shutdown()

        XCTAssertNil(OpenFeatureAPI.shared.getProvider(), "the provider is removed synchronously")
        wait(for: [shutDown], timeout: 5)
    }

    func testProviderWithoutShutdownUsesTheNoOpDefault() async {
        let provider = AlwaysBrokenProvider()
        let eventState = installProviderAndWaitForError(provider)

        await OpenFeatureAPI.shared.shutdownAndWait()

        XCTAssertNil(OpenFeatureAPI.shared.getProvider())
        XCTAssertNotNil(eventState)
    }

    // MARK: - State reset (1.6.2)

    func testShutdownResetsHooksAndEvaluationContext() async {
        await OpenFeatureAPI.shared.setProviderAndWait(
            provider: NoOpProvider(), initialContext: ImmutableContext(targetingKey: "user-1"))
        OpenFeatureAPI.shared.addHooks(hooks: BooleanHookMock())
        XCTAssertEqual(OpenFeatureAPI.shared.getHooks().count, 1)
        XCTAssertEqual(OpenFeatureAPI.shared.getEvaluationContext()?.getTargetingKey(), "user-1")

        await OpenFeatureAPI.shared.shutdownAndWait()

        XCTAssertTrue(OpenFeatureAPI.shared.getHooks().isEmpty)
        XCTAssertNil(OpenFeatureAPI.shared.getEvaluationContext())
        XCTAssertNil(OpenFeatureAPI.shared.getProvider())
    }

    func testShutdownKeepsTheLogger() async {
        let logger = CapturingLogger()
        OpenFeatureAPI.shared.setLogger(logger)
        await OpenFeatureAPI.shared.setProviderAndWait(provider: NoOpProvider())

        await OpenFeatureAPI.shared.shutdownAndWait()

        XCTAssertTrue((OpenFeatureAPI.shared.getLogger() as? CapturingLogger) === logger)
        OpenFeatureAPI.shared.setLogger(nil)
    }

    func testShutdownWithoutProviderStillResetsState() async {
        OpenFeatureAPI.shared.addHooks(hooks: BooleanHookMock())
        await OpenFeatureAPI.shared.setEvaluationContextAndWait(evaluationContext: ImmutableContext(targetingKey: "u"))

        await OpenFeatureAPI.shared.shutdownAndWait()

        XCTAssertTrue(OpenFeatureAPI.shared.getHooks().isEmpty)
        XCTAssertNil(OpenFeatureAPI.shared.getEvaluationContext())
        XCTAssertEqual(OpenFeatureAPI.shared.getProviderStatus(), .notReady)
    }

    func testObserveGoesQuietAfterShutdown() async {
        let provider = NoOpProvider()
        await OpenFeatureAPI.shared.setProviderAndWait(provider: provider)
        let unexpected = expectation(description: "event after shutdown")
        unexpected.isInverted = true
        let subscription = OpenFeatureAPI.shared.observe().dropFirst().sink { _ in unexpected.fulfill() }

        await OpenFeatureAPI.shared.shutdownAndWait()
        _ = provider.initialize(initialContext: nil)  // the retired provider emits .ready again

        await fulfillmentCompat(of: [unexpected], timeout: 0.5)
        subscription.cancel()
    }

    // MARK: - Idempotency and reuse

    func testShutdownIsIdempotent() async {
        let provider = ShutdownSpyProvider()
        await OpenFeatureAPI.shared.setProviderAndWait(provider: provider)

        await OpenFeatureAPI.shared.shutdownAndWait()
        await OpenFeatureAPI.shared.shutdownAndWait()

        XCTAssertEqual(provider.shutdownCalls, 1)
        XCTAssertNil(OpenFeatureAPI.shared.getProvider())
    }

    func testApiIsUsableAgainAfterShutdown() async {
        await OpenFeatureAPI.shared.setProviderAndWait(provider: ShutdownSpyProvider())
        await OpenFeatureAPI.shared.shutdownAndWait()

        let provider = InMemoryProvider(flags: InMemoryTestFlags.all())
        await OpenFeatureAPI.shared.setProviderAndWait(
            provider: provider, initialContext: ImmutableContext(targetingKey: "user-2"))
        OpenFeatureAPI.shared.addHooks(hooks: BooleanHookMock())

        XCTAssertEqual(OpenFeatureAPI.shared.getProviderStatus(), .ready)
        XCTAssertTrue(OpenFeatureAPI.shared.getClient().getValue(key: "boolean-flag", defaultValue: false))
        XCTAssertEqual(OpenFeatureAPI.shared.getEvaluationContext()?.getTargetingKey(), "user-2")
        XCTAssertEqual(OpenFeatureAPI.shared.getHooks().count, 1)
    }

    func testTheSameProviderCanBeSetAgainAfterShutdown() async {
        let provider = InMemoryProvider(flags: InMemoryTestFlags.all())
        await OpenFeatureAPI.shared.setProviderAndWait(provider: provider)
        await OpenFeatureAPI.shared.shutdownAndWait()
        XCTAssertEqual(provider.status, .notReady)

        await OpenFeatureAPI.shared.setProviderAndWait(provider: provider)

        XCTAssertEqual(provider.status, .ready)
        XCTAssertTrue(OpenFeatureAPI.shared.getClient().getValue(key: "boolean-flag", defaultValue: false))
    }

    func testEvaluationAfterShutdownReportsProviderNotReady() async {
        await OpenFeatureAPI.shared.setProviderAndWait(provider: InMemoryProvider(flags: InMemoryTestFlags.all()))
        await OpenFeatureAPI.shared.shutdownAndWait()

        let details = OpenFeatureAPI.shared.getClient().getDetails(key: "boolean-flag", defaultValue: false)

        XCTAssertFalse(details.value)
        XCTAssertEqual(details.errorCode, .providerNotReady)
    }

    // MARK: - Helpers

    private func installProviderAndWaitForReady(_ provider: FeatureProvider) {
        let ready = expectation(description: "Ready")
        let subscription = OpenFeatureAPI.shared.observe().sink { event in
            if case .ready = event {
                ready.fulfill()
            }
        }
        OpenFeatureAPI.shared.setProvider(provider: provider)
        wait(for: [ready], timeout: 5)
        subscription.cancel()
    }

    /// Waits for inverted expectations from an async test without the macOS 13-only `fulfillment(of:)`.
    private func fulfillmentCompat(of expectations: [XCTestExpectation], timeout: TimeInterval) async {
        await withCheckedContinuation { continuation in
            DispatchQueue.global().async {
                _ = XCTWaiter().wait(for: expectations, timeout: timeout)
                continuation.resume()
            }
        }
    }
}
