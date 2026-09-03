import Combine
import Foundation
import OpenFeature
import XCTest

/// Configuration mutation, `.configurationChanged` emission, lifecycle events, and concurrency.
final class InMemoryProviderEventTests: XCTestCase {
    // MARK: - Configuration mutation

    func testPutConfigurationEmitsUnionOfPreviousAndNewFlagKeys() {
        let provider = InMemoryTestFlags.readyProvider(flags: [
            "kept": InMemoryTestFlags.enabledFlag(),
            "removed": InMemoryTestFlags.enabledFlag(),
        ])

        let details = expectConfigurationChanged(from: provider) {
            provider.putConfiguration([
                "kept": InMemoryTestFlags.enabledFlag(),
                "added": InMemoryTestFlags.enabledFlag(),
            ])
        }

        XCTAssertEqual(details?.flagsChanged, ["added", "kept", "removed"])
    }

    func testPutConfigurationReplacesConfiguration() throws {
        let provider = InMemoryTestFlags.readyProvider()
        provider.putConfiguration(InMemoryTestFlags.single(key: "only-flag"))

        XCTAssertEqual(
            try provider.getBooleanEvaluation(key: "only-flag", defaultValue: false, context: nil).value,
            true)
        XCTAssertThrowsError(
            try provider.getBooleanEvaluation(key: "boolean-flag", defaultValue: false, context: nil)
        ) { error in
            XCTAssertEqual((error as? OpenFeatureError)?.errorCode(), .flagNotFound)
        }
    }

    func testUpdateFlagEmitsSingleKeyAndIsResolvableImmediately() throws {
        let provider = InMemoryTestFlags.readyProvider(flags: [:])

        let details = expectConfigurationChanged(from: provider) {
            provider.updateFlag(key: "new-flag", flag: InMemoryTestFlags.enabledFlag())
        }

        XCTAssertEqual(details?.flagsChanged, ["new-flag"])
        XCTAssertEqual(
            try provider.getBooleanEvaluation(key: "new-flag", defaultValue: false, context: nil).value,
            true)
    }

    func testRemoveFlagEmitsSingleKeyAndSubsequentEvaluationThrowsFlagNotFound() {
        let provider = InMemoryTestFlags.readyProvider()

        let details = expectConfigurationChanged(from: provider) {
            provider.removeFlag(key: "boolean-flag")
        }

        XCTAssertEqual(details?.flagsChanged, ["boolean-flag"])
        XCTAssertThrowsError(
            try provider.getBooleanEvaluation(key: "boolean-flag", defaultValue: false, context: nil)
        ) { error in
            XCTAssertEqual((error as? OpenFeatureError)?.errorCode(), .flagNotFound)
        }
    }

    func testRemoveFlagForUnknownKeyEmitsNoEvent() {
        let provider = InMemoryTestFlags.readyProvider()
        var changedKeys: [[String]?] = []
        let expectation = XCTestExpectation(description: "sentinel configurationChanged emitted")
        let cancellable = provider.observe().sink { event in
            if case .configurationChanged(let details) = event {
                changedKeys.append(details?.flagsChanged)
                expectation.fulfill()
            }
        }
        defer { cancellable.cancel() }

        provider.removeFlag(key: "not-a-flag")
        // Waiting on a sentinel mutation, rather than asserting synchronously, gives the no-op
        // above a chance to emit: events are delivered in order on a serial queue.
        provider.removeFlag(key: "boolean-flag")

        XCTAssertEqual(XCTWaiter().wait(for: [expectation], timeout: 5), .completed)
        XCTAssertEqual(changedKeys, [["boolean-flag"]])
    }

    func testConfigurationChangedDoesNotChangeProviderStatus() {
        let provider = InMemoryTestFlags.readyProvider()
        XCTAssertEqual(provider.status, .ready)

        provider.putConfiguration([:])

        XCTAssertEqual(provider.status, .ready)
    }

    func testConfigurationChangedIsObservableThroughOpenFeatureAPI() async {
        let api = OpenFeatureAPI()
        let provider = InMemoryProvider(flags: InMemoryTestFlags.all())
        await api.setProviderAndWait(provider: provider)

        let expectation = XCTestExpectation(description: "configurationChanged observed")
        var observed: ProviderEventDetails?
        let cancellable = api.observe().sink { event in
            if case .configurationChanged(let details) = event {
                observed = details
                expectation.fulfill()
            }
        }
        defer { cancellable.cancel() }

        provider.updateFlag(key: "late-flag", flag: InMemoryTestFlags.enabledFlag())

        await fulfillment(of: [expectation], timeout: 5)
        XCTAssertEqual(observed?.flagsChanged, ["late-flag"])
    }

    // MARK: - Lifecycle

    func testInitializeEmitsReadyAndSetsStatusReady() {
        let provider = InMemoryProvider(flags: InMemoryTestFlags.all())
        XCTAssertEqual(provider.status, .notReady)

        expectEvent(from: provider, description: "ready emitted") { event in
            event == .ready(nil)
        } mutate: {
            _ = provider.initialize(initialContext: nil)
        }

        XCTAssertEqual(provider.status, .ready)
    }

    func testOnContextSetEmitsContextChangedAndKeepsStatusReady() {
        let provider = InMemoryTestFlags.readyProvider()

        expectEvent(from: provider, description: "contextChanged emitted") { event in
            event == .contextChanged(nil)
        } mutate: {
            _ = provider.onContextSet(oldContext: nil, newContext: MutableContext())
        }

        XCTAssertEqual(provider.status, .ready)
    }

    // MARK: - Concurrency

    func testConcurrentEvaluationsAndConfigurationUpdatesAreSafe() {
        let provider = InMemoryTestFlags.readyProvider()

        DispatchQueue.concurrentPerform(iterations: 100) { iteration in
            if iteration.isMultiple(of: 10) {
                provider.putConfiguration(InMemoryTestFlags.all())
            } else {
                _ = try? provider.getBooleanEvaluation(
                    key: "boolean-flag", defaultValue: false, context: nil)
            }
        }

        XCTAssertEqual(provider.status, .ready)
    }

    func testConfigurationChangedSubscriberCallingBackIntoProviderDoesNotDeadlock() {
        let provider = InMemoryTestFlags.readyProvider(flags: [:])
        let expectation = XCTestExpectation(description: "reentrant subscriber returned")

        let cancellable = provider.observe().sink { event in
            guard case .configurationChanged = event else { return }
            _ = provider.flags
            expectation.fulfill()
        }
        defer { cancellable.cancel() }

        provider.updateFlag(key: "flag", flag: InMemoryTestFlags.enabledFlag())

        XCTAssertEqual(XCTWaiter().wait(for: [expectation], timeout: 5), .completed)
    }

    // MARK: - Helpers

    /// Events are delivered on a serial queue, so they cannot be asserted on synchronously after
    /// the call that emits them.
    private func expectEvent(
        from provider: InMemoryProvider,
        description: String,
        matching predicate: @escaping (ProviderEvent) -> Bool,
        mutate: () -> Void
    ) {
        let expectation = XCTestExpectation(description: description)
        let cancellable = provider.observe().sink { event in
            if predicate(event) {
                expectation.fulfill()
            }
        }
        defer { cancellable.cancel() }

        mutate()

        XCTAssertEqual(XCTWaiter().wait(for: [expectation], timeout: 5), .completed, description)
    }

    private func expectConfigurationChanged(
        from provider: InMemoryProvider,
        _ mutate: () -> Void
    ) -> ProviderEventDetails? {
        var details: ProviderEventDetails?
        expectEvent(from: provider, description: "configurationChanged emitted") { event in
            if case .configurationChanged(let eventDetails) = event {
                details = eventDetails
                return true
            }
            return false
        } mutate: {
            mutate()
        }
        return details
    }
}
