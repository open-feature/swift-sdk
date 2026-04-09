import Combine
import XCTest

@testable import OpenFeature

/// Tests that document provider lifecycle behavior, including the expectation that
/// event handlers can call back into the API without deadlocking (handlers run on
/// a dedicated queue, so they never run while holding the API's state lock).
final class ProviderLifecycleTests: XCTestCase {
    /// **Expected behavior: does not deadlock.** When the provider completes initialization
    /// synchronously (e.g. NoOpProvider), the SDK must still deliver the `.ready` event to
    /// subscribers and allow the subscriber to call back into the API (e.g. `getProviderStatus()`)
    /// without deadlock. The SDK achieves this by running `api.observe()` handlers on a dedicated
    /// queue, so the handler never runs on a thread that holds `stateQueue`.
    func testSyncProviderWithSubscriberCallingBackIntoAPI_DoesNotDeadlock() {
        let api = OpenFeatureAPI()
        let subscriberDidComplete = XCTestExpectation(
            description: "Subscriber received .ready and getProviderStatus() returned without deadlock")

        let eventHandler = EventHandler()
        // Create a provider that emits .ready event
        let provider = MockProvider(
            observe: { eventHandler.observe() }
        )

        let cancellable =
            api
            .observe()
            .sink { event in
                if case .ready = event {
                    _ = api.getProviderStatus()
                    subscriberDidComplete.fulfill()
                }
            }

        DispatchQueue.global().async {
            api.setProvider(provider: provider)
            // Emit .ready event after provider is set
            eventHandler.send(.ready())
        }

        let result = XCTWaiter.wait(for: [subscriberDidComplete], timeout: 1.5)
        cancellable.cancel()

        switch result {
        case .completed:
            break
        default:
            XCTFail(
                "Expected no deadlock: subscriber that calls getProviderStatus() from a .ready "
                    + "handler should complete. If this test hangs or times out, event handlers "
                    + "may be running under the API's state lock."
            )
        }
    }

    /// **Expected behavior: does not deadlock.** With an async provider, the subscriber runs
    /// on a different thread than the one that held the lock, so callbacks are safe. This test
    /// reinforces that a subscriber can call back into the API from a .ready handler.
    func testAsyncProviderWithSubscriberCallingBackIntoAPI_DoesNotDeadlock() async {
        var cancellables = Set<AnyCancellable>()
        let api = OpenFeatureAPI()
        let expectation = XCTestExpectation(
            description: "Subscriber received .ready and getProviderStatus() returned without deadlock")

        let eventHandler = EventHandler()
        // Swift requires argument labels here to avoid binding this closure to `onContextSet`.
        // swiftlint:disable trailing_closure
        let provider = MockProvider(
            initialize: { _ in
                try await Task.sleep(nanoseconds: 50_000_000)  // 50ms
                eventHandler.send(.ready())
            },
            observe: { eventHandler.observe() }
        )
        // swiftlint:enable trailing_closure
        api
            .observe()
            .sink { event in
                if case .ready = event {
                    _ = api.getProviderStatus()
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)

        await api.setProviderAndWait(provider: provider)
        await fulfillment(of: [expectation], timeout: 2)
    }
}
