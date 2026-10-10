import Combine
import Foundation
import XCTest

@testable import OpenFeature

/// The provider side of shutdown (specification 2.5.1–2.5.3): `ProviderStatusTracker.reset()` and the `shutdown`
/// of the SDK's own providers, exercised directly rather than through the API.
final class ProviderShutdownTests: XCTestCase {
    // MARK: - ProviderStatusTracker.reset()

    func testResetRevertsToNotReady() {
        let tracker = ProviderStatusTracker()
        tracker.send(.ready(nil))
        XCTAssertEqual(tracker.status, .ready)

        tracker.reset()

        XCTAssertEqual(tracker.status, .notReady)
    }

    func testResetRevertsFromEveryStatus() {
        let events: [ProviderEvent] = [
            .ready(nil),
            .error(nil),
            .stale(nil),
            .reconciling(nil),
            .error(ProviderEventDetails(errorCode: .providerFatal)),
        ]

        for event in events {
            let tracker = ProviderStatusTracker()
            tracker.send(event)
            XCTAssertNotEqual(tracker.status, .notReady, "\(event)")

            tracker.reset()

            XCTAssertEqual(tracker.status, .notReady, "\(event)")
        }
    }

    func testResetEmitsNoEvent() {
        let tracker = ProviderStatusTracker()
        let unexpected = expectation(description: "event from reset")
        unexpected.isInverted = true
        let subscription = tracker.observe().sink { _ in unexpected.fulfill() }

        tracker.reset()

        wait(for: [unexpected], timeout: 0.3)
        subscription.cancel()
    }

    func testSubscribersAfterResetReceiveNoReplay() {
        let tracker = ProviderStatusTracker()
        tracker.send(.ready(nil))
        tracker.reset()
        let unexpected = expectation(description: "replayed event")
        unexpected.isInverted = true

        let subscription = tracker.observe().sink { _ in unexpected.fulfill() }

        wait(for: [unexpected], timeout: 0.3)
        subscription.cancel()
    }

    func testResetIsIdempotentAndSafeBeforeAnyEvent() {
        let tracker = ProviderStatusTracker()

        tracker.reset()
        tracker.reset()

        XCTAssertEqual(tracker.status, .notReady)
    }

    func testTrackerWorksNormallyAfterReset() {
        let tracker = ProviderStatusTracker()
        tracker.send(.ready(nil))
        tracker.reset()
        let ready = expectation(description: "ready after reset")
        let subscription = tracker.observe().sink { event in
            if case .ready = event {
                ready.fulfill()
            }
        }

        tracker.send(.ready(nil))

        wait(for: [ready], timeout: 5)
        XCTAssertEqual(tracker.status, .ready)
        subscription.cancel()
    }

    // MARK: - Default implementation

    func testDefaultShutdownResolvesImmediately() {
        let provider = AlwaysBrokenProvider()
        let resolved = expectation(description: "resolved")

        let subscription = provider.shutdown().sink { _ in resolved.fulfill() }

        wait(for: [resolved], timeout: 5)
        subscription.cancel()
    }

    // MARK: - NoOpProvider

    func testNoOpProviderRevertsToNotReady() {
        let provider = NoOpProvider()
        _ = provider.initialize(initialContext: nil)
        XCTAssertEqual(provider.status, .ready)

        let resolved = expectation(description: "resolved")
        let subscription = provider.shutdown().sink { _ in resolved.fulfill() }

        wait(for: [resolved], timeout: 5)
        XCTAssertEqual(provider.status, .notReady)
        subscription.cancel()
    }

    // MARK: - InMemoryProvider

    func testInMemoryProviderRevertsToNotReadyAndKeepsItsFlags() {
        let provider = InMemoryTestFlags.readyProvider()
        XCTAssertEqual(provider.status, .ready)
        let flagsBefore = provider.flags.keys.sorted()

        let resolved = expectation(description: "resolved")
        let subscription = provider.shutdown().sink { _ in resolved.fulfill() }

        wait(for: [resolved], timeout: 5)
        XCTAssertEqual(provider.status, .notReady)
        XCTAssertEqual(provider.flags.keys.sorted(), flagsBefore)
        subscription.cancel()
    }

    func testInMemoryProviderCanBeInitializedAgainAfterShutdown() {
        let provider = InMemoryTestFlags.readyProvider()
        _ = provider.shutdown()
        XCTAssertEqual(provider.status, .notReady)

        _ = provider.initialize(initialContext: nil)

        XCTAssertEqual(provider.status, .ready)
        XCTAssertEqual(
            try provider.getBooleanEvaluation(key: "boolean-flag", defaultValue: false, context: nil).value, true)
    }

    func testInMemoryProviderShutdownIsIdempotent() {
        let provider = InMemoryTestFlags.readyProvider()

        _ = provider.shutdown()
        _ = provider.shutdown()

        XCTAssertEqual(provider.status, .notReady)
    }

    // MARK: - MultiProvider

    func testMultiProviderShutsDownEveryChildAndRevertsToNotReady() {
        let first = ShutdownSpyProvider(name: "first")
        let second = ShutdownSpyProvider(name: "second")
        let multi = MultiProvider(providers: [first, second])
        let initialized = expectation(description: "initialized")
        let initSubscription = multi.initialize(initialContext: nil).sink { _ in initialized.fulfill() }
        wait(for: [initialized], timeout: 5)
        XCTAssertEqual(multi.status, .ready)

        let resolved = expectation(description: "shut down")
        let subscription = multi.shutdown().sink { _ in resolved.fulfill() }

        wait(for: [resolved], timeout: 5)
        XCTAssertEqual(first.shutdownCalls, 1)
        XCTAssertEqual(second.shutdownCalls, 1)
        XCTAssertEqual(first.status, .notReady)
        XCTAssertEqual(second.status, .notReady)
        XCTAssertEqual(multi.status, .notReady)
        initSubscription.cancel()
        subscription.cancel()
    }

    func testMultiProviderShutdownWaitsForEveryChild() {
        let fast = ShutdownSpyProvider(name: "fast")
        let slow = ShutdownSpyProvider(name: "slow", holdShutdown: true)
        let multi = MultiProvider(providers: [fast, slow])
        let initialized = expectation(description: "initialized")
        let initSubscription = multi.initialize(initialContext: nil).sink { _ in initialized.fulfill() }
        wait(for: [initialized], timeout: 5)

        let resolvedTooEarly = expectation(description: "resolved before every child finished")
        resolvedTooEarly.isInverted = true
        let resolved = expectation(description: "shut down")
        let subscription = multi.shutdown().sink { _ in
            resolvedTooEarly.fulfill()
            resolved.fulfill()
        }

        wait(for: [resolvedTooEarly], timeout: 0.5)
        XCTAssertEqual(fast.shutdownCalls, 1)
        XCTAssertEqual(slow.shutdownCalls, 1)
        XCTAssertEqual(multi.status, .ready, "status is reverted only once every child has finished")
        slow.completeShutdown()
        wait(for: [resolved], timeout: 5)
        XCTAssertEqual(multi.status, .notReady)
        initSubscription.cancel()
        subscription.cancel()
    }

    func testMultiProviderWithoutChildrenShutsDownImmediately() {
        let multi = MultiProvider(providers: [])
        let resolved = expectation(description: "shut down")

        let subscription = multi.shutdown().sink { _ in resolved.fulfill() }

        wait(for: [resolved], timeout: 5)
        XCTAssertEqual(multi.status, .notReady)
        subscription.cancel()
    }
}
