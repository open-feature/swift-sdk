import Combine
import Foundation
import Logging

/// The interface implemented by upstream flag providers to resolve flags for their service.
///
/// Providers are responsible for managing their own ``status`` and for emitting events
/// according to the OpenFeature specification. The easiest way to satisfy both
/// requirements is to delegate to ``ProviderStatusTracker``:
///
/// ```swift
/// final class MyProvider: FeatureProvider {
///     private let statusTracker = ProviderStatusTracker()
///
///     // Delegate status and event publishing to the tracker
///     var status: ProviderStatus { statusTracker.status }
///     func observe() -> AnyPublisher<ProviderEvent, Never> { statusTracker.observe() }
///
///     func initialize(initialContext: EvaluationContext?) -> Future<Void, Never> {
///         Future { promise in
///             // Emit any non-.notReady event before resolving.
///             // .ready and .error are the most common outcomes.
///             self.statusTracker.send(.ready(nil))
///             promise(.success(()))
///         }
///     }
///
///     func onContextSet(oldContext: EvaluationContext?, newContext: EvaluationContext) -> Future<Void, Never> {
///         Future { promise in
///             // If no work is needed, resolve immediately (no events required).
///             // If reconciliation is required:
///             //   self.statusTracker.send(.reconciling(nil))
///             //   ... re-evaluate with new context ...
///             //   self.statusTracker.send(.contextChanged(nil))  // or .error(nil) on failure
///             //   promise(.success(()))
///             promise(.success(()))
///         }
///     }
///
///     // ... flag evaluation methods ...
/// }
/// ```
///
/// ``ProviderStatusTracker`` automatically keeps `status` in sync with emitted events,
/// handles thread safety, and replays the current status to new subscribers.
public protocol FeatureProvider: EventPublisher {
    var hooks: [any Hook] { get }
    var metadata: ProviderMetadata { get }

    /// The current lifecycle status of the provider.
    ///
    /// The provider is solely responsible for keeping this value up to date.
    /// It must be `.notReady` before `initialize` is called, and must reflect
    /// the most recently emitted event at all times per the OpenFeature specification.
    ///
    /// This property must be **thread-safe**: the SDK may read it concurrently
    /// from flag evaluation paths on any thread.
    ///
    /// The recommended way to satisfy these requirements is to use
    /// ``ProviderStatusTracker`` and expose its `status` property directly.
    var status: ProviderStatus { get }

    /// Called by OpenFeatureAPI when the provider is first registered.
    ///
    /// Perform any asynchronous initialisation work (e.g. fetching initial flag
    /// configuration, establishing a streaming connection) inside this method.
    ///
    /// **Required status transition:** emit at least one event before the returned
    /// `Future` resolves, so that `status` transitions away from `.notReady`. The
    /// most common outcomes are `.ready` on success and `.error` on failure, but
    /// any non-`.notReady` status is valid.
    ///
    /// Resolve the `Future` only after emitting the event ensures that callers
    /// of `setProviderAndWait` see the correct status immediately.
    ///
    /// Note: `initialize` is called exactly once, when the provider is registered.
    /// The SDK never calls it again, regardless of the resulting status.
    func initialize(initialContext: EvaluationContext?) -> Future<Void, Never>

    /// Called by OpenFeatureAPI whenever the active `EvaluationContext` changes.
    ///
    /// Two valid approaches:
    /// 1. **No work needed** — resolve the `Future` immediately without emitting any event.
    /// 2. **Reconciliation required** — emit `.reconciling` first, perform the work, then
    ///    emit `.contextChanged` on success or `.error` on failure, and resolve the `Future`.
    ///
    /// **Concurrency note:** lifecycle calls are serialized — this method is not called
    /// again until the previous call to `initialize` or `onContextSet` has returned (i.e.
    /// the `Future` has been created and returned). However, the SDK does **not** wait for
    /// the returned `Future` to resolve before dispatching the next call. This means
    /// `onContextSet` may be called while a previous lifecycle `Future` is still doing
    /// async work. Providers that perform async reconciliation should handle this
    /// gracefully, e.g. by cancelling any in-flight work when a new call arrives.
    func onContextSet(
        oldContext: EvaluationContext?,
        newContext: EvaluationContext,
    ) -> Future<Void, Never>

    /// Evaluates a boolean feature flag.
    ///
    /// - Warning: This method will be removed before the 1.0 release.
    ///   Implement ``getBooleanEvaluation(key:defaultValue:context:logger:)`` instead.
    func getBooleanEvaluation(key: String, defaultValue: Bool, context: EvaluationContext?) throws
        -> ProviderEvaluation<
            Bool
        >

    /// Evaluates a string feature flag.
    ///
    /// - Warning: This method will be removed before the 1.0 release.
    ///   Implement ``getStringEvaluation(key:defaultValue:context:logger:)`` instead.
    func getStringEvaluation(key: String, defaultValue: String, context: EvaluationContext?) throws
        -> ProviderEvaluation<
            String
        >

    /// Evaluates an integer feature flag.
    ///
    /// - Warning: This method will be removed before the 1.0 release.
    ///   Implement ``getIntegerEvaluation(key:defaultValue:context:logger:)`` instead.
    func getIntegerEvaluation(key: String, defaultValue: Int64, context: EvaluationContext?) throws
        -> ProviderEvaluation<
            Int64
        >

    /// Evaluates a double feature flag.
    ///
    /// - Warning: This method will be removed before the 1.0 release.
    ///   Implement ``getDoubleEvaluation(key:defaultValue:context:logger:)`` instead.
    func getDoubleEvaluation(key: String, defaultValue: Double, context: EvaluationContext?) throws
        -> ProviderEvaluation<
            Double
        >

    /// Evaluates an object feature flag.
    ///
    /// - Warning: This method will be removed before the 1.0 release.
    ///   Implement ``getObjectEvaluation(key:defaultValue:context:logger:)`` instead.
    func getObjectEvaluation(key: String, defaultValue: Value, context: EvaluationContext?) throws
        -> ProviderEvaluation<
            Value
        >

    // Logger-enabled evaluation methods

    /// Evaluates a boolean feature flag.
    ///
    /// Override this method to receive and use the logger during flag evaluation.
    /// If not overridden, the default implementation delegates to
    /// ``getBooleanEvaluation(key:defaultValue:context:)``.
    func getBooleanEvaluation(key: String, defaultValue: Bool, context: EvaluationContext?, logger: Logger?) throws
        -> ProviderEvaluation<
            Bool
        >

    /// Evaluates a string feature flag.
    ///
    /// Override this method to receive and use the logger during flag evaluation.
    /// If not overridden, the default implementation delegates to
    /// ``getStringEvaluation(key:defaultValue:context:)``.
    func getStringEvaluation(key: String, defaultValue: String, context: EvaluationContext?, logger: Logger?) throws
        -> ProviderEvaluation<
            String
        >

    /// Evaluates an integer feature flag.
    ///
    /// Override this method to receive and use the logger during flag evaluation.
    /// If not overridden, the default implementation delegates to
    /// ``getIntegerEvaluation(key:defaultValue:context:)``.
    func getIntegerEvaluation(key: String, defaultValue: Int64, context: EvaluationContext?, logger: Logger?) throws
        -> ProviderEvaluation<
            Int64
        >

    /// Evaluates a double feature flag.
    ///
    /// Override this method to receive and use the logger during flag evaluation.
    /// If not overridden, the default implementation delegates to
    /// ``getDoubleEvaluation(key:defaultValue:context:)``.
    func getDoubleEvaluation(key: String, defaultValue: Double, context: EvaluationContext?, logger: Logger?) throws
        -> ProviderEvaluation<
            Double
        >

    /// Evaluates an object feature flag.
    ///
    /// Override this method to receive and use the logger during flag evaluation.
    /// If not overridden, the default implementation delegates to
    /// ``getObjectEvaluation(key:defaultValue:context:)``.
    func getObjectEvaluation(key: String, defaultValue: Value, context: EvaluationContext?, logger: Logger?) throws
        -> ProviderEvaluation<
            Value
        >

    /// Performs tracking of a particular action or application state.
    /// - Parameters:
    ///   - key: Event name to track
    ///   - context: Evaluation context used in flag evaluation
    ///   - details: Data pertinent to a particular tracking event
    func track(key: String, context: (any EvaluationContext)?, details: (any TrackingEventDetails)?) throws
}

extension FeatureProvider {
    public func track(key: String, context: (any EvaluationContext)?, details: (any TrackingEventDetails)?) throws {
        // Default to no-op
    }

    // Default implementations for logger-enabled methods that delegate to original methods
    public func getBooleanEvaluation(key: String, defaultValue: Bool, context: EvaluationContext?, logger: Logger?)
        throws
        -> ProviderEvaluation<Bool>
    {
        return try getBooleanEvaluation(key: key, defaultValue: defaultValue, context: context)
    }

    public func getStringEvaluation(key: String, defaultValue: String, context: EvaluationContext?, logger: Logger?)
        throws
        -> ProviderEvaluation<String>
    {
        return try getStringEvaluation(key: key, defaultValue: defaultValue, context: context)
    }

    public func getIntegerEvaluation(key: String, defaultValue: Int64, context: EvaluationContext?, logger: Logger?)
        throws
        -> ProviderEvaluation<Int64>
    {
        return try getIntegerEvaluation(key: key, defaultValue: defaultValue, context: context)
    }

    public func getDoubleEvaluation(key: String, defaultValue: Double, context: EvaluationContext?, logger: Logger?)
        throws
        -> ProviderEvaluation<Double>
    {
        return try getDoubleEvaluation(key: key, defaultValue: defaultValue, context: context)
    }

    public func getObjectEvaluation(key: String, defaultValue: Value, context: EvaluationContext?, logger: Logger?)
        throws
        -> ProviderEvaluation<Value>
    {
        return try getObjectEvaluation(key: key, defaultValue: defaultValue, context: context)
    }
}
