import Foundation

/// Interface used to resolve flags of varying types.
public protocol Client: Features, Tracking {
    var metadata: ClientMetadata { get }

    /// The hooks associated to this client.
    var hooks: [any Hook] { get }

    /// Adds hooks for evaluation.
    /// Hooks are run in the order they're added in the before stage. They are run in reverse order for all
    /// other stages.
    func addHooks(_ hooks: any Hook...)

    /// Sets the logger for this client.
    ///
    /// A client logger takes precedence over the API-level logger and is overridden by a logger passed in
    /// ``FlagEvaluationOptions``. Pass `nil` to fall back to the API-level logger.
    /// - Parameter logger: The logger handed to providers during flag evaluation, or `nil` to clear it.
    func setLogger(_ logger: (any OpenFeatureLogger)?)
}
