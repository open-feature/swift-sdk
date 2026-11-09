import Combine
import XCTest

@testable import OpenFeature
import OpenFeatureIsolated

/// Isolated API instances (specification section 1.8): `OpenFeatureAPI.isolated()` creates
/// independent instances with their own provider, evaluation context, hooks and events, and a
/// provider must not be claimed by two API instances at the same time.
final class IsolatedAPIInstanceTests: XCTestCase {
    // MARK: - Independent state (spec 1.8.1, 1.8.2)

    func testFactoryReturnsIndependentInstances() throws {
        let first = OpenFeatureAPI.isolated()
        let second = OpenFeatureAPI.isolated()

        XCTAssertTrue(first !== second)

        let provider = ReadyProvider()
        first.setProvider(provider: provider)

        let owner = try XCTUnwrap(first.getProvider())
        XCTAssertTrue(owner as AnyObject === provider)
        XCTAssertNil(second.getProvider())
    }

    func testEvaluationContextAndHooksAreIndependent() {
        let first = OpenFeatureAPI.isolated()
        let second = OpenFeatureAPI.isolated()

        first.setEvaluationContext(evaluationContext: ImmutableContext(targetingKey: "first-key"))
        first.addHooks(hooks: NoOpHook())

        XCTAssertEqual(first.getEvaluationContext()?.getTargetingKey(), "first-key")
        XCTAssertEqual(first.getHooks().count, 1)
        XCTAssertNil(second.getEvaluationContext())
        XCTAssertTrue(second.getHooks().isEmpty)
    }

    func testIsolatedStateIsIndependentOfTheSingleton() async throws {
        let isolated = OpenFeatureAPI.isolated()

        // Snapshot the singleton's configuration: other suites may have left it set up,
        // so isolation is asserted as invariance rather than a pristine singleton.
        let sharedProviderBefore = OpenFeatureAPI.shared.getProvider().map { String(describing: $0) }
        let sharedContextKeyBefore = OpenFeatureAPI.shared.getEvaluationContext()?.getTargetingKey()

        let provider = ReadyProvider()
        isolated.setProvider(provider: provider)
        isolated.setEvaluationContext(evaluationContext: ImmutableContext(targetingKey: "isolated-key"))

        // Configuring the isolated instance does not touch the singleton.
        XCTAssertEqual(OpenFeatureAPI.shared.getProvider().map { String(describing: $0) }, sharedProviderBefore)
        XCTAssertEqual(OpenFeatureAPI.shared.getEvaluationContext()?.getTargetingKey(), sharedContextKeyBefore)

        // Configuration on the singleton does not leak into isolated instances either.
        await OpenFeatureAPI.shared.setProviderAndWait(provider: ReadyProvider())
        OpenFeatureAPI.shared.setEvaluationContext(evaluationContext: ImmutableContext(targetingKey: "shared-key"))

        let isolatedProvider = try XCTUnwrap(isolated.getProvider())
        XCTAssertTrue(isolatedProvider as AnyObject === provider)
        XCTAssertEqual(isolated.getEvaluationContext()?.getTargetingKey(), "isolated-key")

        await OpenFeatureAPI.shared.shutdownAndWait()
    }

    func testClientsEvaluateAgainstTheirOwnInstanceProvider() async {
        let first = OpenFeatureAPI.isolated()
        let second = OpenFeatureAPI.isolated()

        await first.setProviderAndWait(provider: ReadyProvider())

        // ReadyProvider resolves booleans as true; second has no provider and returns the default.
        XCTAssertTrue(first.getClient().getBooleanValue(key: "flag", defaultValue: false))
        XCTAssertFalse(second.getClient().getBooleanValue(key: "flag", defaultValue: false))
    }

    // MARK: - Provider ownership (spec 1.8.4)

    func testProviderClaimedByAnotherInstanceIsRejected() async throws {
        let first = OpenFeatureAPI.isolated()
        let second = OpenFeatureAPI.isolated()
        let logger = CapturingLogger()
        second.setLogger(logger)

        let provider = ReadyProvider()
        await first.setProviderAndWait(provider: provider)

        // The rejection stays observable: it is logged, the rejected instance is left
        // unchanged, and the existing ownership is intact.
        await second.setProviderAndWait(provider: provider)

        XCTAssertEqual(logger.messages(at: .error).count, 1)
        XCTAssertTrue(
            logger.messages(at: .error)[0].contains("already claimed by another OpenFeature API instance"))
        XCTAssertNil(second.getProvider())
        let owner = try XCTUnwrap(first.getProvider())
        XCTAssertTrue(owner as AnyObject === provider)
    }

    func testProviderCanBeReclaimedAfterShutdown() async throws {
        let first = OpenFeatureAPI.isolated()
        let second = OpenFeatureAPI.isolated()

        let provider = ReadyProvider()
        await first.setProviderAndWait(provider: provider)
        await first.shutdownAndWait()

        await second.setProviderAndWait(provider: provider)
        let newOwner = try XCTUnwrap(second.getProvider())
        XCTAssertTrue(newOwner as AnyObject === provider)
    }

    func testProviderCanBeReclaimedAfterClearProvider() async throws {
        let first = OpenFeatureAPI.isolated()
        let second = OpenFeatureAPI.isolated()

        let provider = ReadyProvider()
        await first.setProviderAndWait(provider: provider)
        await first.clearProviderAndWait()

        await second.setProviderAndWait(provider: provider)
        let newOwner = try XCTUnwrap(second.getProvider())
        XCTAssertTrue(newOwner as AnyObject === provider)
    }

    func testProviderCanBeResetOnTheSameInstance() async throws {
        let api = OpenFeatureAPI.isolated()
        let provider = ReadyProvider()
        await api.setProviderAndWait(provider: provider)

        // Re-setting the same provider on the same instance is not a claim violation.
        api.setProvider(provider: provider)
        let owner = try XCTUnwrap(api.getProvider())
        XCTAssertTrue(owner as AnyObject === provider)
    }

    func testValueProvidersAreExemptFromOwnership() async {
        let first = OpenFeatureAPI.isolated()
        let second = OpenFeatureAPI.isolated()

        // Value-type providers cannot be keyed by identity; every copy carries independent state.
        await first.setProviderAndWait(provider: ValueProvider())
        await second.setProviderAndWait(provider: ValueProvider())
    }

    // MARK: - Events (spec 1.8.2)

    func testEventsDoNotCrossInstances() async {
        let first = OpenFeatureAPI.isolated()
        let second = OpenFeatureAPI.isolated()

        await first.setProviderAndWait(provider: ReadyProvider())
        await second.setProviderAndWait(provider: ErrorProvider())

        let readyExpectation = expectation(description: "ready event on first")
        let errorExpectation = expectation(description: "error event on second")

        var cancellables: [AnyCancellable] = []
        let firstEvents = first.observe().sink { event in
            if case .ready = event {
                readyExpectation.fulfill()
            } else if case .error = event {
                XCTFail("second instance's provider event leaked into first")
            }
        }
        let secondEvents = second.observe().sink { event in
            if case .error = event {
                errorExpectation.fulfill()
            } else if case .ready = event {
                XCTFail("first instance's provider event leaked into second")
            }
        }
        firstEvents.store(in: &cancellables)
        secondEvents.store(in: &cancellables)

        await fulfillment(of: [readyExpectation, errorExpectation], timeout: 5)
    }
}

/// Records every message it receives, so tests can assert what the SDK logs.
private final class CapturingLogger: OpenFeatureLogger {
    private let lock = NSLock()
    private var messagesByLevel: [Level: [String]] = [:]

    enum Level {
        case debug
        case info
        case warning
        case error
    }

    func messages(at level: Level) -> [String] {
        lock.withLock { messagesByLevel[level] ?? [] }
    }

    func debug(_ message: @autoclosure () -> String) {
        record(.debug, message())
    }

    func info(_ message: @autoclosure () -> String) {
        record(.info, message())
    }

    func warning(_ message: @autoclosure () -> String) {
        record(.warning, message())
    }

    func error(_ message: @autoclosure () -> String) {
        record(.error, message())
    }

    private func record(_ level: Level, _ message: String) {
        lock.withLock { messagesByLevel[level, default: []].append(message) }
    }
}

/// A minimal class provider that emits `.ready` on initialize and resolves booleans as `true`.
private final class ReadyProvider: FeatureProvider {
    private struct Metadata: ProviderMetadata {
        var name: String? = "ReadyProvider"
    }

    var hooks: [any Hook] = []
    var metadata: ProviderMetadata = Metadata()
    private let statusTracker = ProviderStatusTracker()
    var status: ProviderStatus { statusTracker.status }

    func observe() -> AnyPublisher<ProviderEvent, Never> {
        statusTracker.observe()
    }

    func initialize(initialContext: EvaluationContext?) -> Future<Void, Never> {
        Future { promise in
            self.statusTracker.send(.ready(nil))
            promise(.success(()))
        }
    }

    func onContextSet(oldContext: EvaluationContext?, newContext: EvaluationContext) -> Future<Void, Never> {
        Future { $0(.success(())) }
    }

    func getBooleanEvaluation(key: String, defaultValue: Bool, context: EvaluationContext?) throws
        -> ProviderEvaluation<Bool>
    {
        ProviderEvaluation(value: true)
    }

    func getStringEvaluation(key: String, defaultValue: String, context: EvaluationContext?) throws
        -> ProviderEvaluation<String>
    {
        ProviderEvaluation(value: defaultValue)
    }

    func getIntegerEvaluation(key: String, defaultValue: Int64, context: EvaluationContext?) throws
        -> ProviderEvaluation<Int64>
    {
        ProviderEvaluation(value: defaultValue)
    }

    func getDoubleEvaluation(key: String, defaultValue: Double, context: EvaluationContext?) throws
        -> ProviderEvaluation<Double>
    {
        ProviderEvaluation(value: defaultValue)
    }

    func getObjectEvaluation(key: String, defaultValue: Value, context: EvaluationContext?) throws
        -> ProviderEvaluation<Value>
    {
        ProviderEvaluation(value: defaultValue)
    }
}

/// A minimal class provider that emits `.error` on initialize.
private final class ErrorProvider: FeatureProvider {
    private struct Metadata: ProviderMetadata {
        var name: String? = "ErrorProvider"
    }

    var hooks: [any Hook] = []
    var metadata: ProviderMetadata = Metadata()
    private let statusTracker = ProviderStatusTracker()
    var status: ProviderStatus { statusTracker.status }

    func observe() -> AnyPublisher<ProviderEvent, Never> {
        statusTracker.observe()
    }

    func initialize(initialContext: EvaluationContext?) -> Future<Void, Never> {
        Future { promise in
            self.statusTracker.send(.error(nil))
            promise(.success(()))
        }
    }

    func onContextSet(oldContext: EvaluationContext?, newContext: EvaluationContext) -> Future<Void, Never> {
        Future { $0(.success(())) }
    }

    func getBooleanEvaluation(key: String, defaultValue: Bool, context: EvaluationContext?) throws
        -> ProviderEvaluation<Bool>
    {
        ProviderEvaluation(value: defaultValue)
    }

    func getStringEvaluation(key: String, defaultValue: String, context: EvaluationContext?) throws
        -> ProviderEvaluation<String>
    {
        ProviderEvaluation(value: defaultValue)
    }

    func getIntegerEvaluation(key: String, defaultValue: Int64, context: EvaluationContext?) throws
        -> ProviderEvaluation<Int64>
    {
        ProviderEvaluation(value: defaultValue)
    }

    func getDoubleEvaluation(key: String, defaultValue: Double, context: EvaluationContext?) throws
        -> ProviderEvaluation<Double>
    {
        ProviderEvaluation(value: defaultValue)
    }

    func getObjectEvaluation(key: String, defaultValue: Value, context: EvaluationContext?) throws
        -> ProviderEvaluation<Value>
    {
        ProviderEvaluation(value: defaultValue)
    }
}

/// A minimal value-type provider, to exercise the ownership exemption for providers that
/// cannot be keyed by object identity.
private struct ValueProvider: FeatureProvider {
    private struct Metadata: ProviderMetadata {
        var name: String? = "ValueProvider"
    }

    var hooks: [any Hook] = []
    var metadata: ProviderMetadata = Metadata()
    private let statusTracker = ProviderStatusTracker()
    var status: ProviderStatus { statusTracker.status }

    func observe() -> AnyPublisher<ProviderEvent, Never> {
        statusTracker.observe()
    }

    func initialize(initialContext: EvaluationContext?) -> Future<Void, Never> {
        Future { promise in
            self.statusTracker.send(.ready(nil))
            promise(.success(()))
        }
    }

    func onContextSet(oldContext: EvaluationContext?, newContext: EvaluationContext) -> Future<Void, Never> {
        Future { $0(.success(())) }
    }

    func getBooleanEvaluation(key: String, defaultValue: Bool, context: EvaluationContext?) throws
        -> ProviderEvaluation<Bool>
    {
        ProviderEvaluation(value: defaultValue)
    }

    func getStringEvaluation(key: String, defaultValue: String, context: EvaluationContext?) throws
        -> ProviderEvaluation<String>
    {
        ProviderEvaluation(value: defaultValue)
    }

    func getIntegerEvaluation(key: String, defaultValue: Int64, context: EvaluationContext?) throws
        -> ProviderEvaluation<Int64>
    {
        ProviderEvaluation(value: defaultValue)
    }

    func getDoubleEvaluation(key: String, defaultValue: Double, context: EvaluationContext?) throws
        -> ProviderEvaluation<Double>
    {
        ProviderEvaluation(value: defaultValue)
    }

    func getObjectEvaluation(key: String, defaultValue: Value, context: EvaluationContext?) throws
        -> ProviderEvaluation<Value>
    {
        ProviderEvaluation(value: defaultValue)
    }
}

/// A no-op hook, for asserting hook-state independence between instances.
private struct NoOpHook: Hook {
    typealias HookValue = Bool
}
