import Combine
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

    /// Observes the events of the provider this client evaluates flags with.
    ///
    /// Use the returned publisher to react to a particular event type, for example to re-evaluate flags on
    /// ``ProviderEvent/configurationChanged(_:)``. A subscriber added once the provider is already in a given state
    /// receives an event reflecting that state right away, provided the provider replays its status as
    /// ``ProviderStatusTracker`` does. Cancel the subscription to stop observing.
    ///
    /// When the provider is replaced, the publisher follows the new one.
    /// - Returns: A publisher of the events of the client's provider.
    func observe() -> AnyPublisher<ProviderEvent, Never>
}
