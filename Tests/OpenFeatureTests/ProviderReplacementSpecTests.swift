import Combine
import Foundation
import XCTest

@testable import OpenFeature
import OpenFeatureIsolated

/// Provider mutators shut down the provider they retire (specification 1.1.2.3): `setProvider` for the one it
/// replaces, `clearProvider` for the one it removes.
final class ProviderReplacementSpecTests: XCTestCase {
    /// A fresh API instance per test: XCTest creates a new test-case object for every test
    /// method, so tests share no state and need no setUp reset of the shared singleton.
    private let api = OpenFeatureAPI.isolated()

    // MARK: - setProvider

    func testReplacingAProviderShutsDownThePreviousOne() async {
        let first = ShutdownSpyProvider(name: "first")
        let second = ShutdownSpyProvider(name: "second")

        await api.setProviderAndWait(provider: first)
        XCTAssertEqual(first.shutdownCalls, 0)

        await api.setProviderAndWait(provider: second)

        XCTAssertEqual(first.shutdownCalls, 1)
        XCTAssertEqual(second.shutdownCalls, 0)
        XCTAssertEqual(first.status, .notReady)
        XCTAssertEqual(second.status, .ready)
    }

    func testEveryReplacementShutsDownExactlyTheRetiredProvider() async {
        let first = ShutdownSpyProvider(name: "first")
        let second = ShutdownSpyProvider(name: "second")
        let third = ShutdownSpyProvider(name: "third")

        await api.setProviderAndWait(provider: first)
        await api.setProviderAndWait(provider: second)
        await api.setProviderAndWait(provider: third)

        XCTAssertEqual(first.shutdownCalls, 1)
        XCTAssertEqual(second.shutdownCalls, 1)
        XCTAssertEqual(third.shutdownCalls, 0)
    }

    func testThePreviousProviderIsShutDownBeforeTheNewOneInitializes() async {
        let lock = NSLock()
        var calls: [String] = []
        let record: (String) -> Void = { call in lock.withLock { calls.append(call) } }
        let first = ShutdownSpyProvider(name: "first", onLifecycle: record)
        let second = ShutdownSpyProvider(name: "second", onLifecycle: record)

        await api.setProviderAndWait(provider: first)
        await api.setProviderAndWait(provider: second)

        XCTAssertEqual(calls, ["initialize:first", "shutdown:first", "initialize:second"])
    }

    func testReplacementWithFireAndForgetSetProviderShutsDownThePreviousOne() {
        let shutDown = expectation(description: "first shut down")
        let first = ShutdownSpyProvider(name: "first") { call in
            if call == "shutdown:first" {
                shutDown.fulfill()
            }
        }
        let second = ShutdownSpyProvider(name: "second")
        installProviderAndWaitForReady(first)

        installProviderAndWaitForReady(second)

        wait(for: [shutDown], timeout: 5)
        XCTAssertEqual(first.shutdownCalls, 1)
        XCTAssertEqual(second.shutdownCalls, 0)
    }

    func testReSettingTheSameInstanceDoesNotShutItDown() async {
        let provider = ShutdownSpyProvider()
        await api.setProviderAndWait(provider: provider)

        await api.setProviderAndWait(provider: provider)

        XCTAssertEqual(provider.shutdownCalls, 0)
        XCTAssertEqual(provider.status, .ready)
        XCTAssertTrue(api.getProvider() as AnyObject === provider)
    }

    func testTheNewProviderServesEvaluationsWhileThePreviousOneIsShuttingDown() async {
        let slow = ShutdownSpyProvider(name: "slow", holdShutdown: true)
        await api.setProviderAndWait(provider: slow)
        let replacement = InMemoryProvider(flags: InMemoryTestFlags.all())

        await api.setProviderAndWait(provider: replacement)

        XCTAssertEqual(slow.shutdownCalls, 1)
        XCTAssertTrue(api.getClient().getValue(key: "boolean-flag", defaultValue: false))
        slow.completeShutdown()
    }

    // MARK: - clearProvider

    func testClearProviderShutsDownTheRemovedProvider() async {
        let provider = ShutdownSpyProvider()
        await api.setProviderAndWait(provider: provider)

        await api.clearProviderAndWait()

        XCTAssertEqual(provider.shutdownCalls, 1)
        XCTAssertEqual(provider.status, .notReady)
        XCTAssertNil(api.getProvider())
        XCTAssertEqual(api.getProviderStatus(), .notReady)
    }

    func testClearProviderAndWaitReturnsOnlyAfterTheProviderFinishes() {
        let provider = ShutdownSpyProvider(holdShutdown: true)
        installProviderAndWaitForReady(provider)
        let returnedTooEarly = expectation(description: "clearProviderAndWait returned before the provider finished")
        returnedTooEarly.isInverted = true
        let finished = expectation(description: "clearProviderAndWait returned")

        Task {
            await api.clearProviderAndWait()
            returnedTooEarly.fulfill()
            finished.fulfill()
        }

        wait(for: [returnedTooEarly], timeout: 0.5)
        XCTAssertEqual(provider.shutdownCalls, 1)
        provider.completeShutdown()
        wait(for: [finished], timeout: 5)
    }

    func testFireAndForgetClearProviderShutsDownInTheBackground() {
        let shutDown = expectation(description: "shutdown called")
        let provider = ShutdownSpyProvider { call in
            if call == "shutdown:spy" {
                shutDown.fulfill()
            }
        }
        installProviderAndWaitForReady(provider)

        api.clearProvider()

        XCTAssertNil(api.getProvider())
        wait(for: [shutDown], timeout: 5)
    }

    func testClearProviderKeepsHooksAndEvaluationContext() async {
        await api.setProviderAndWait(
            provider: NoOpProvider(), initialContext: ImmutableContext(targetingKey: "user-1"))
        api.addHooks(hooks: BooleanHookMock())

        await api.clearProviderAndWait()

        XCTAssertEqual(api.getHooks().count, 1)
        XCTAssertEqual(api.getEvaluationContext()?.getTargetingKey(), "user-1")
    }

    func testClearProviderWithoutProviderIsANoOp() async {
        await api.clearProviderAndWait()

        XCTAssertNil(api.getProvider())
        XCTAssertEqual(api.getProviderStatus(), .notReady)
    }

    func testAProviderIsShutDownOnlyOncePerRegistration() async {
        let provider = ShutdownSpyProvider()
        await api.setProviderAndWait(provider: provider)

        await api.clearProviderAndWait()
        await api.clearProviderAndWait()
        await api.shutdownAndWait()

        XCTAssertEqual(provider.shutdownCalls, 1)
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
}
