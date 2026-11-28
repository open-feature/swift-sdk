import Combine
import Foundation
import XCTest

@testable import OpenFeature
import OpenFeatureIsolated

/// `OpenFeatureAPI.shutdown()` / `shutdownAndWait()` (specification 1.6.1, 1.6.2): the provider is shut down and
/// the API's state is reset, after which the API can be used again.
final class ShutdownSpecTests: XCTestCase {
    /// A fresh API instance per test: XCTest creates a new test-case object for every test
    /// method, so tests share no state and need no setUp reset of the shared singleton.
    private let api = OpenFeatureAPI.isolated()

    // MARK: - Provider shutdown

    func testShutdownCallsTheProviderShutdownAndRemovesIt() async {
        let provider = ShutdownSpyProvider()
        await api.setProviderAndWait(provider: provider)
        XCTAssertEqual(api.getProviderStatus(), .ready)

        await api.shutdownAndWait()

        XCTAssertEqual(provider.shutdownCalls, 1)
        XCTAssertNil(api.getProvider())
        XCTAssertEqual(api.getProviderStatus(), .notReady)
        XCTAssertEqual(provider.status, .notReady)
    }

    func testShutdownAndWaitReturnsOnlyAfterTheProviderFinishes() {
        let provider = ShutdownSpyProvider(holdShutdown: true)
        installProviderAndWaitForReady(provider)
        let returnedTooEarly = expectation(description: "shutdownAndWait returned before the provider finished")
        returnedTooEarly.isInverted = true
        let finished = expectation(description: "shutdownAndWait returned")

        Task {
            await api.shutdownAndWait()
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

        api.shutdown()

        XCTAssertNil(api.getProvider(), "the provider is removed synchronously")
        wait(for: [shutDown], timeout: 5)
    }

    func testProviderWithoutShutdownUsesTheNoOpDefault() async {
        let provider = AlwaysBrokenProvider()
        let eventState = installProviderAndWaitForError(provider, on: api)

        await api.shutdownAndWait()

        XCTAssertNil(api.getProvider())
        XCTAssertNotNil(eventState)
    }

    // MARK: - State reset (1.6.2)

    func testShutdownResetsHooksAndEvaluationContext() async {
        await api.setProviderAndWait(
            provider: NoOpProvider(), initialContext: ImmutableContext(targetingKey: "user-1"))
        api.addHooks(hooks: BooleanHookMock())
        XCTAssertEqual(api.getHooks().count, 1)
        XCTAssertEqual(api.getEvaluationContext()?.getTargetingKey(), "user-1")

        await api.shutdownAndWait()

        XCTAssertTrue(api.getHooks().isEmpty)
        XCTAssertNil(api.getEvaluationContext())
        XCTAssertNil(api.getProvider())
    }

    func testShutdownKeepsTheLogger() async {
        let logger = CapturingLogger()
        api.setLogger(logger)
        await api.setProviderAndWait(provider: NoOpProvider())

        await api.shutdownAndWait()

        XCTAssertTrue((api.getLogger() as? CapturingLogger) === logger)
        api.setLogger(nil)
    }

    func testShutdownWithoutProviderStillResetsState() async {
        api.addHooks(hooks: BooleanHookMock())
        await api.setEvaluationContextAndWait(evaluationContext: ImmutableContext(targetingKey: "u"))

        await api.shutdownAndWait()

        XCTAssertTrue(api.getHooks().isEmpty)
        XCTAssertNil(api.getEvaluationContext())
        XCTAssertEqual(api.getProviderStatus(), .notReady)
    }

    func testObserveGoesQuietAfterShutdown() async {
        let provider = NoOpProvider()
        await api.setProviderAndWait(provider: provider)
        let unexpected = expectation(description: "event after shutdown")
        unexpected.isInverted = true
        let subscription = api.observe().dropFirst().sink { _ in unexpected.fulfill() }

        await api.shutdownAndWait()
        _ = provider.initialize(initialContext: nil)  // the retired provider emits .ready again

        await fulfillmentCompat(of: [unexpected], timeout: 0.5)
        subscription.cancel()
    }

    // MARK: - Idempotency and reuse

    func testShutdownIsIdempotent() async {
        let provider = ShutdownSpyProvider()
        await api.setProviderAndWait(provider: provider)

        await api.shutdownAndWait()
        await api.shutdownAndWait()

        XCTAssertEqual(provider.shutdownCalls, 1)
        XCTAssertNil(api.getProvider())
    }

    func testApiIsUsableAgainAfterShutdown() async {
        await api.setProviderAndWait(provider: ShutdownSpyProvider())
        await api.shutdownAndWait()

        let provider = InMemoryProvider(flags: InMemoryTestFlags.all())
        await api.setProviderAndWait(
            provider: provider, initialContext: ImmutableContext(targetingKey: "user-2"))
        api.addHooks(hooks: BooleanHookMock())

        XCTAssertEqual(api.getProviderStatus(), .ready)
        XCTAssertTrue(api.getClient().getValue(key: "boolean-flag", defaultValue: false))
        XCTAssertEqual(api.getEvaluationContext()?.getTargetingKey(), "user-2")
        XCTAssertEqual(api.getHooks().count, 1)
    }

    func testTheSameProviderCanBeSetAgainAfterShutdown() async {
        let provider = InMemoryProvider(flags: InMemoryTestFlags.all())
        await api.setProviderAndWait(provider: provider)
        await api.shutdownAndWait()
        XCTAssertEqual(provider.status, .notReady)

        await api.setProviderAndWait(provider: provider)

        XCTAssertEqual(provider.status, .ready)
        XCTAssertTrue(api.getClient().getValue(key: "boolean-flag", defaultValue: false))
    }

    func testEvaluationAfterShutdownReportsProviderNotReady() async {
        await api.setProviderAndWait(provider: InMemoryProvider(flags: InMemoryTestFlags.all()))
        await api.shutdownAndWait()

        let details = api.getClient().getDetails(key: "boolean-flag", defaultValue: false)

        XCTAssertFalse(details.value)
        XCTAssertEqual(details.errorCode, .providerNotReady)
    }

    // MARK: - Helpers

    private func installProviderAndWaitForReady(_ provider: FeatureProvider) {
        let ready = expectation(description: "Ready")
        // A subscription may replay the current provider's `.ready` and then also deliver the newly
        // installed provider's `.ready` when it races a replacement, so tolerate over-fulfillment.
        ready.assertForOverFulfill = false
        let subscription = api.observe().sink { event in
            if case .ready = event {
                ready.fulfill()
            }
        }
        api.setProvider(provider: provider)
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
