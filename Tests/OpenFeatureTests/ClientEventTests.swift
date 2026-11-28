import Combine
import Foundation
import OpenFeature
import XCTest

/// Client-level event handlers (specification 5.2): `Client.observe()` delivers the events of the client's provider.
/// Every test uses its own `OpenFeatureAPI` so that no events leak in from other tests.
final class ClientEventTests: XCTestCase {
    func testClientReceivesEventsOfItsProvider() async {
        let api = OpenFeatureAPI()
        let provider = InMemoryProvider(flags: InMemoryTestFlags.all())
        await api.setProviderAndWait(provider: provider)
        let recorder = EventRecorder(api.getClient().observe())

        await fulfillment(of: [recorder.expectation(eventCount: 1)], timeout: 5)
        provider.updateFlag(key: "new-flag", flag: InMemoryTestFlags.enabledFlag())
        await fulfillment(of: [recorder.expectation(eventCount: 2)], timeout: 5)

        XCTAssertEqual(
            recorder.events,
            [
                .ready(nil),
                .configurationChanged(ProviderEventDetails(flagsChanged: ["new-flag"], message: "flag added/updated")),
            ])
    }

    func testHandlerAddedBeforeProviderIsSetReceivesReadyEvent() async {
        let api = OpenFeatureAPI()
        let recorder = EventRecorder(api.getClient().observe())

        api.setProvider(provider: InMemoryProvider())
        await fulfillment(of: [recorder.expectation(eventCount: 1)], timeout: 5)

        XCTAssertEqual(recorder.events, [.ready(nil)])
    }

    func testHandlerAddedAfterProviderIsReadyRunsImmediately() async {
        let api = OpenFeatureAPI()
        await api.setProviderAndWait(provider: InMemoryProvider())

        let recorder = EventRecorder(api.getClient().observe())
        await fulfillment(of: [recorder.expectation(eventCount: 1)], timeout: 5)

        XCTAssertEqual(recorder.events, [.ready(nil)])
    }

    func testHandlerFollowsReplacedProvider() async {
        let api = OpenFeatureAPI()
        let previous = InMemoryProvider()
        await api.setProviderAndWait(provider: previous)
        let recorder = EventRecorder(api.getClient().observe())
        await fulfillment(of: [recorder.expectation(eventCount: 1)], timeout: 5)

        let current = InMemoryProvider()
        await api.setProviderAndWait(provider: current)
        await fulfillment(of: [recorder.expectation(eventCount: 2)], timeout: 5)
        previous.updateFlag(key: "previous-flag", flag: InMemoryTestFlags.enabledFlag())
        current.updateFlag(key: "current-flag", flag: InMemoryTestFlags.enabledFlag())
        await fulfillment(of: [recorder.expectation(eventCount: 3)], timeout: 5)

        XCTAssertEqual(
            recorder.events,
            [
                .ready(nil),
                .ready(nil),
                .configurationChanged(
                    ProviderEventDetails(flagsChanged: ["current-flag"], message: "flag added/updated")),
            ])
    }

    func testEveryClientOfTheApiReceivesTheEvents() async {
        let api = OpenFeatureAPI()
        let provider = InMemoryProvider()
        await api.setProviderAndWait(provider: provider)
        let unnamed = EventRecorder(api.getClient().observe())
        let named = EventRecorder(api.getClient(name: "checkout", version: nil).observe())

        provider.updateFlag(key: "new-flag", flag: InMemoryTestFlags.enabledFlag())
        await fulfillment(of: [unnamed.expectation(eventCount: 2)], timeout: 5)
        await fulfillment(of: [named.expectation(eventCount: 2)], timeout: 5)

        XCTAssertEqual(unnamed.events, named.events)
        XCTAssertEqual(unnamed.events.count, 2)
    }

    func testClientDoesNotReceiveEventsOfAnotherApiInstance() async {
        let api = OpenFeatureAPI()
        let otherApi = OpenFeatureAPI()
        let provider = InMemoryProvider()
        let otherProvider = InMemoryProvider()
        await api.setProviderAndWait(provider: provider)
        await otherApi.setProviderAndWait(provider: otherProvider)
        let recorder = EventRecorder(api.getClient().observe())
        await fulfillment(of: [recorder.expectation(eventCount: 1)], timeout: 5)

        otherProvider.updateFlag(key: "other-flag", flag: InMemoryTestFlags.enabledFlag())
        provider.updateFlag(key: "own-flag", flag: InMemoryTestFlags.enabledFlag())
        await fulfillment(of: [recorder.expectation(eventCount: 2)], timeout: 5)

        XCTAssertEqual(
            recorder.events,
            [
                .ready(nil),
                .configurationChanged(ProviderEventDetails(flagsChanged: ["own-flag"], message: "flag added/updated")),
            ])
    }

    func testCancelledHandlerReceivesNoFurtherEvents() async {
        let api = OpenFeatureAPI()
        let provider = InMemoryProvider()
        await api.setProviderAndWait(provider: provider)
        let client = api.getClient()
        let cancelled = EventRecorder(client.observe())
        await fulfillment(of: [cancelled.expectation(eventCount: 1)], timeout: 5)

        cancelled.cancel()
        let active = EventRecorder(client.observe())
        provider.updateFlag(key: "new-flag", flag: InMemoryTestFlags.enabledFlag())
        await fulfillment(of: [active.expectation(eventCount: 2)], timeout: 5)

        XCTAssertEqual(cancelled.events, [.ready(nil)])
    }
}

/// Records the events a publisher delivers, so tests can wait for them and assert on their order.
private final class EventRecorder {
    private let lock = NSLock()
    private var recorded: [ProviderEvent] = []
    private var pending: [(count: Int, expectation: XCTestExpectation)] = []
    private var cancellable: AnyCancellable?

    init(_ publisher: AnyPublisher<ProviderEvent, Never>) {
        cancellable = publisher.sink { [weak self] event in
            self?.record(event)
        }
    }

    /// Every event received so far, in delivery order.
    var events: [ProviderEvent] {
        lock.withLock { recorded }
    }

    /// Stops receiving events.
    func cancel() {
        cancellable?.cancel()
    }

    /// An expectation fulfilled once `eventCount` events have been received.
    func expectation(eventCount: Int) -> XCTestExpectation {
        let expectation = XCTestExpectation(description: "\(eventCount) events")
        let reached: Bool = lock.withLock {
            guard recorded.count < eventCount else { return true }
            pending.append((eventCount, expectation))
            return false
        }
        if reached {
            expectation.fulfill()
        }
        return expectation
    }

    private func record(_ event: ProviderEvent) {
        let reached: [XCTestExpectation] = lock.withLock {
            recorded.append(event)
            let reached = pending.filter { $0.count == recorded.count }.map { $0.expectation }
            pending.removeAll { $0.count == recorded.count }
            return reached
        }
        reached.forEach { $0.fulfill() }
    }
}
