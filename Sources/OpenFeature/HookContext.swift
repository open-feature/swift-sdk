import Foundation

/// The context a ``Hook`` receives at every stage of a flag evaluation.
///
/// Everything but ``hookData`` describes the evaluation and is the same for every hook that runs in it.
/// ``hookData`` is created fresh for each hook on each evaluation, so a hook can carry state between its own stages
/// without that state leaking to other hooks or later evaluations.
public struct HookContext<T> {
    public var flagKey: String
    public var type: FlagValueType
    public var defaultValue: T
    public var ctx: EvaluationContext?
    public var clientMetadata: ClientMetadata?
    public var providerMetadata: ProviderMetadata?
    public var hookData = HookData()
}
