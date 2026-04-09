import Combine
import XCTest

@testable import OpenFeature

/// Tests for ProviderStatusTracker's critical functionality:
/// - Status transition logic
/// - Atomic replay mechanism
/// - Subscription lifecycle
/// - Deadlock prevention
/// - Thread safety and race conditions
final class ProviderStatusTrackerTests: XCTestCase {
    var cancellables: Set<AnyCancellable>!

    override func setUp() {
        super.setUp()
        cancellables = Set<AnyCancellable>()
    }

    override func tearDown() {
        cancellables.removeAll()
        super.tearDown()
    }

    // MARK: - Group 1: Critical Status Transitions

    /// Tests that .error(.providerFatal) transitions to .fatal status (special case)
    func testSend_ErrorEventWithProviderFatal_UpdatesStatusToFatal() {
        let tracker = ProviderStatusTracker()

        let fatalEvent = ProviderEvent.error(ProviderEventDetails(errorCode: .providerFatal))
        tracker.send(fatalEvent)

        XCTAssertEqual(tracker.status, .fatal)
    }

    /// Tests that .contextChanged event transitions to .ready status
    func testSend_ContextChangedEvent_UpdatesStatusToReady() {
        let tracker = ProviderStatusTracker()

        tracker.send(.contextChanged(nil))

        XCTAssertEqual(tracker.status, .ready)
    }

    /// Tests that .configurationChanged keeps current status (no-op case)
    func testSend_ConfigurationChangedEvent_DoesNotChangeStatus() {
        let tracker = ProviderStatusTracker()

        // Set tracker to .ready first
        tracker.send(.ready(nil))
        XCTAssertEqual(tracker.status, .ready)

        // Send .configurationChanged
        tracker.send(.configurationChanged(nil))

        // Status should remain .ready
        XCTAssertEqual(tracker.status, .ready)
    }

    // MARK: - Group 2: Atomic Replay Mechanism

    /// Tests that .notReady status doesn't trigger an initial replay
    func testObserve_WhenStatusNotReady_NoInitialEventReplayed() {
        let tracker = ProviderStatusTracker()
        XCTAssertEqual(tracker.status, .notReady)  // Default state

        let expectation = XCTestExpectation(description: "Should not receive initial event")
        expectation.isInverted = true  // We expect this NOT to be fulfilled

        tracker.observe()
            .sink { _ in expectation.fulfill() }
            .store(in: &cancellables)

        wait(for: [expectation], timeout: 0.5)
    }

    /// Tests that .fatal status replays as .error(.providerFatal)
    func testObserve_WhenStatusFatal_ReplaysErrorWithProviderFatal() {
        let tracker = ProviderStatusTracker()
        tracker.send(.error(ProviderEventDetails(errorCode: .providerFatal)))
        XCTAssertEqual(tracker.status, .fatal)

        let expectation = XCTestExpectation(description: "Received replayed error event")

        tracker.observe()
            .sink { event in
                if case .error(let details) = event {
                    XCTAssertEqual(details?.errorCode, .providerFatal)
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)

        wait(for: [expectation], timeout: 5)
    }

    /// Tests that concurrent send/subscribe operations maintain atomicity (no missed events)
    func testObserve_AtomicReplayToLiveStream_NoMissedEvents() {
        let tracker = ProviderStatusTracker()
        tracker.send(.ready(nil))

        let receivedEventsExpectation = XCTestExpectation(description: "Received all events")
        let lock = NSLock()
        var receivedEvents: [ProviderEvent] = []
        let expectedCount = 3  // 1 replay + 2 live

        // Subscribe and immediately send events on another queue
        DispatchQueue.global().async {
            tracker.observe()
                .sink { event in
                    let count = lock.withLock {
                        receivedEvents.append(event)
                        return receivedEvents.count
                    }
                    if count == expectedCount {
                        receivedEventsExpectation.fulfill()
                    }
                }
                .store(in: &self.cancellables)

            tracker.send(.stale(nil))
            tracker.send(.reconciling(nil))
        }

        wait(for: [receivedEventsExpectation], timeout: 5)

        // Verify we got all events: initial .ready replay + .stale + .reconciling
        let events = lock.withLock { receivedEvents }
        XCTAssertEqual(events.count, 3)
        if case .ready = events[0] {
        } else {
            XCTFail("Expected first event to be .ready (replay)")
        }
        if case .stale = events[1] {
        } else {
            XCTFail("Expected second event to be .stale")
        }
        if case .reconciling = events[2] {
        } else {
            XCTFail("Expected third event to be .reconciling")
        }
    }

    // MARK: - Group 4: Subscription Lifecycle

    /// Tests that cancellation stops receiving events
    func testCancel_StopsReceivingEvents() {
        let tracker = ProviderStatusTracker()
        tracker.send(.ready(nil))

        let firstEventExpectation = XCTestExpectation(description: "Received first event")
        let secondEventExpectation = XCTestExpectation(description: "Should not receive second event")
        secondEventExpectation.isInverted = true

        var eventCount = 0
        let cancellable = tracker.observe()
            .sink { _ in
                eventCount += 1
                if eventCount == 1 {
                    firstEventExpectation.fulfill()
                } else if eventCount == 2 {
                    secondEventExpectation.fulfill()
                }
            }

        wait(for: [firstEventExpectation], timeout: 5)

        // Cancel subscription
        cancellable.cancel()

        // Send another event - should not be received
        tracker.send(.stale(nil))
        wait(for: [secondEventExpectation], timeout: 1)

        XCTAssertEqual(eventCount, 1)
    }

    // MARK: - Group 5: Deadlock Prevention

    /// Tests that subscriber callback can read status without deadlock
    func testSubscriberCallback_CallingStatusProperty_DoesNotDeadlock() {
        let tracker = ProviderStatusTracker()
        tracker.send(.ready(nil))

        let expectation = XCTestExpectation(
            description: "Callback read status and returned without deadlock")

        tracker.observe()
            .sink { _ in
                // Reading status should not deadlock
                _ = tracker.status
                expectation.fulfill()
            }
            .store(in: &cancellables)

        let result = XCTWaiter.wait(for: [expectation], timeout: 1.5)

        switch result {
        case .completed:
            break
        default:
            XCTFail(
                "Expected no deadlock: subscriber callback that reads tracker.status should complete. "
                    + "If this test hangs or times out, callbacks may be running under statusLock."
            )
        }
    }

    /// Tests that reentrant send() from callback doesn't deadlock
    func testSubscriberCallback_ReentrantSend_DoesNotDeadlock() {
        let tracker = ProviderStatusTracker()
        tracker.send(.ready(nil))

        let expectation = XCTestExpectation(
            description: "Callback called send() and returned without deadlock")

        var callCount = 0
        tracker.observe()
            .sink { event in
                callCount += 1
                // Only call send once to avoid infinite loop
                if callCount == 1, case .ready = event {
                    tracker.send(.stale(nil))
                }
                if callCount == 2 {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)

        let result = XCTWaiter.wait(for: [expectation], timeout: 1.5)

        switch result {
        case .completed:
            break
        default:
            XCTFail(
                "Expected no deadlock: subscriber callback that calls tracker.send() should complete. "
                    + "If this test hangs or times out, callbacks may be running under serializationLock."
            )
        }
    }

    /// Tests that send() returns immediately (callbacks execute asynchronously)
    func testSubscriberCallback_SynchronousCompletion_DoesNotBlock() {
        let tracker = ProviderStatusTracker()

        let slowCallbackStarted = XCTestExpectation(description: "Slow callback started")
        let sendReturned = XCTestExpectation(description: "send() returned")

        tracker.observe()
            .sink { _ in
                slowCallbackStarted.fulfill()
                // Simulate slow callback
                Thread.sleep(forTimeInterval: 0.5)
            }
            .store(in: &cancellables)

        // Send event on background queue
        DispatchQueue.global().async {
            tracker.send(.ready(nil))
            sendReturned.fulfill()
        }

        // send() should return before callback completes
        wait(for: [sendReturned], timeout: 0.3)

        // But callback should still eventually execute
        wait(for: [slowCallbackStarted], timeout: 5)
    }

    /// Tests that initial replay callback can call tracker methods without deadlock
    func testInitialReplay_WithCallbackCallingTracker_DoesNotDeadlock() {
        let tracker = ProviderStatusTracker()
        tracker.send(.ready(nil))

        let expectation = XCTestExpectation(
            description: "Initial replay callback called tracker methods without deadlock")

        tracker.observe()
            .sink { _ in
                // Call various tracker methods from replay callback
                _ = tracker.status
                tracker.send(.stale(nil))
                expectation.fulfill()
            }
            .store(in: &cancellables)

        let result = XCTWaiter.wait(for: [expectation], timeout: 1.5)

        switch result {
        case .completed:
            break
        default:
            XCTFail(
                "Expected no deadlock: initial replay callback that calls tracker methods should complete. "
                    + "If this test hangs or times out, replay may be executing synchronously under locks."
            )
        }
    }

    // MARK: - Group 6: Critical Race Conditions

    /// Tests concurrent send and subscribe operations
    func testConcurrentSendAndSubscribe_NoRaces() {
        let tracker = ProviderStatusTracker()
        let iterations = 100
        let expectation = XCTestExpectation(description: "All operations completed")
        expectation.expectedFulfillmentCount = iterations * 2  // sends + subscribes

        let queue = DispatchQueue(label: "test.concurrent", attributes: .concurrent)

        for _ in 0..<iterations {
            // Concurrent sends
            queue.async {
                tracker.send(.ready(nil))
                expectation.fulfill()
            }

            // Concurrent subscribes
            queue.async {
                tracker.observe()
                    .sink { _ in }
                    .store(in: &self.cancellables)
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 10)

        // If we get here without crashes or hangs, the test passes
        XCTAssertEqual(tracker.status, .ready)
    }

    /// Tests that multiple subscribers each get independent initial replay
    func testMultipleSubscribers_DifferentInitialReplay() {
        let tracker = ProviderStatusTracker()
        tracker.send(.ready(nil))

        let firstSubscriberExpectation = XCTestExpectation(description: "First subscriber received .ready")
        let secondSubscriberExpectation = XCTestExpectation(description: "Second subscriber received .stale")

        // First subscriber
        tracker.observe()
            .sink { event in
                if case .ready = event {
                    firstSubscriberExpectation.fulfill()
                }
            }
            .store(in: &cancellables)

        wait(for: [firstSubscriberExpectation], timeout: 5)

        // Change status
        tracker.send(.stale(nil))

        // Second subscriber should see .stale as initial replay
        tracker.observe()
            .sink { event in
                if case .stale = event {
                    secondSubscriberExpectation.fulfill()
                }
            }
            .store(in: &cancellables)

        wait(for: [secondSubscriberExpectation], timeout: 5)
    }
}
