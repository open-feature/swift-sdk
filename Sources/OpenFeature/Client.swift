import Foundation

/// Interface used to resolve flags of varying types.
public protocol Client: Features {
    var metadata: ClientMetadata { get }

    /// The hooks associated to this client.
    var hooks: [any Hook] { get }

    /// Adds hooks for evaluation.
    /// Hooks are run in the order they're added in the before stage. They are run in reverse order for all
    /// other stages.
    func addHooks(_ hooks: any Hook...)

    /// Add a handler for a particular provider event
    ///  - Parameter observer: The object observing the event.
    ///  - Parameter selector: The selector to call for this event.
    ///  - Parameter event: The event to listen for.
    func addHandler(observer: Any, selector: Selector, event: ProviderEvent)

    /// Remove a handler for a particular provider event
    ///  - Parameter observer: The object observing the event.
    ///  - Parameter event: The event being listened to.
    func removeHandler(observer: Any, event: ProviderEvent)
}
