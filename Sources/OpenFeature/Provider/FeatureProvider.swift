import Foundation
import Logging

/// The interface implemented by upstream flag providers to resolve flags for their service.
public protocol FeatureProvider: EventPublisher {
    var hooks: [any Hook] { get }
    var metadata: ProviderMetadata { get }

    /// Called by OpenFeatureAPI whenever the new Provider is registered
    /// This must throw in case of error, using OpenFeature errors whenever possible
    /// It is expected that the implementer is slow (e.g. network), hence the async nature of the protocol
    func initialize(initialContext: EvaluationContext?) async throws

    /// Called by OpenFeatureAPI whenever a new EvaluationContext is set by the application
    /// This must throw in case of error, using OpenFeature errors whenever possible
    /// It is expected that the implementer is slow (e.g. network), hence the async nature of the protocol
    func onContextSet(oldContext: EvaluationContext?, newContext: EvaluationContext) async throws

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
