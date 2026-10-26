import Combine
import Foundation
import XCTest

@testable import OpenFeature

/// Provider mutators shut down the provider they retire (specification 1.1.2.3): `setProvider` for the one it
/// replaces, `clearProvider` for the one it removes.
final class ProviderReplacementSpecTests: XCTestCase {
    override func setUp() async throws {
        try await super.setUp()
        await OpenFeatureAPI.shared.shutdownAndWait()
    }

    // MARK: - setProvider

    func testReplacingAProviderShutsDownThePreviousOne() async {
        let first = ShutdownSpyProvider(name: "first")
        let second = ShutdownSpyProvider(name: "second")

        await OpenFeatureAPI.shared.setProviderAndWait(provider: first)
        XCTAssertEqual(first.shutdownCalls, 0)

        await OpenFeatureAPI.shared.setProviderAndWait(provider: second)

        XCTAssertEqual(first.shutdownCalls, 1)
        XCTAssertEqual(second.shutdownCalls, 0)
        XCTAssertEqual(first.status, .notReady)
        XCTAssertEqual(second.status, .ready)
    }

    func testEveryReplacementShutsDownExactlyTheRetiredProvider() async {
        let first = ShutdownSpyProvider(name: "first")
        let second = ShutdownSpyProvider(name: "second")
        let third = ShutdownSpyProvider(name: "third")

        await OpenFeatureAPI.shared.setProviderAndWait(provider: first)
        await OpenFeatureAPI.shared.setProviderAndWait(provider: second)
        await OpenFeatureAPI.shared.setProviderAndWait(provider: third)

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

        await OpenFeatureAPI.shared.setProviderAndWait(provider: first)
        await OpenFeatureAPI.shared.setProviderAndWait(provider: second)

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
        await OpenFeatureAPI.shared.setProviderAndWait(provider: provider)

        await OpenFeatureAPI.shared.setProviderAndWait(provider: provider)

        XCTAssertEqual(provider.shutdownCalls, 0)
        XCTAssertEqual(provider.status, .ready)
        XCTAssertTrue(OpenFeatureAPI.shared.getProvider() as AnyObject === provider)
    }

    func testTheNewProviderServesEvaluationsWhileThePreviousOneIsShuttingDown() async {
        let slow = ShutdownSpyProvider(name: "slow", holdShutdown: true)
        await OpenFeatureAPI.shared.setProviderAndWait(provider: slow)
        let replacement = InMemoryProvider(flags: InMemoryTestFlags.all())

        await OpenFeatureAPI.shared.setProviderAndWait(provider: replacement)

        XCTAssertEqual(slow.shutdownCalls, 1)
        XCTAssertTrue(OpenFeatureAPI.shared.getClient().getValue(key: "boolean-flag", defaultValue: false))
        slow.completeShutdown()
    }

    // MARK: - clearProvider

    func testClearProviderShutsDownTheRemovedProvider() async {
        let provider = ShutdownSpyProvider()
        await OpenFeatureAPI.shared.setProviderAndWait(provider: provider)

        await OpenFeatureAPI.shared.clearProviderAndWait()

        XCTAssertEqual(provider.shutdownCalls, 1)
        XCTAssertEqual(provider.status, .notReady)
        XCTAssertNil(OpenFeatureAPI.shared.getProvider())
        XCTAssertEqual(OpenFeatureAPI.shared.getProviderStatus(), .notReady)
    }

    func testClearProviderAndWaitReturnsOnlyAfterTheProviderFinishes() {
        let provider = ShutdownSpyProvider(holdShutdown: true)
        installProviderAndWaitForReady(provider)
        let returnedTooEarly = expectation(description: "clearProviderAndWait returned before the provider finished")
        returnedTooEarly.isInverted = true
        let finished = expectation(description: "clearProviderAndWait returned")

        Task {
            await OpenFeatureAPI.shared.clearProviderAndWait()
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

        OpenFeatureAPI.shared.clearProvider()

        XCTAssertNil(OpenFeatureAPI.shared.getProvider())
        wait(for: [shutDown], timeout: 5)
    }

    func testClearProviderKeepsHooksAndEvaluationContext() async {
        await OpenFeatureAPI.shared.setProviderAndWait(
            provider: NoOpProvider(), initialContext: ImmutableContext(targetingKey: "user-1"))
        OpenFeatureAPI.shared.addHooks(hooks: BooleanHookMock())

        await OpenFeatureAPI.shared.clearProviderAndWait()

        XCTAssertEqual(OpenFeatureAPI.shared.getHooks().count, 1)
        XCTAssertEqual(OpenFeatureAPI.shared.getEvaluationContext()?.getTargetingKey(), "user-1")
    }

    func testClearProviderWithoutProviderIsANoOp() async {
        await OpenFeatureAPI.shared.clearProviderAndWait()

        XCTAssertNil(OpenFeatureAPI.shared.getProvider())
        XCTAssertEqual(OpenFeatureAPI.shared.getProviderStatus(), .notReady)
    }

    func testAProviderIsShutDownOnlyOncePerRegistration() async {
        let provider = ShutdownSpyProvider()
        await OpenFeatureAPI.shared.setProviderAndWait(provider: provider)

        await OpenFeatureAPI.shared.clearProviderAndWait()
        await OpenFeatureAPI.shared.clearProviderAndWait()
        await OpenFeatureAPI.shared.shutdownAndWait()

        XCTAssertEqual(provider.shutdownCalls, 1)
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
}
