import Foundation

/// A data struct to hold immutable context that ``Hook`` instances use.
public struct HookContext<T> {
    public var flagKey: String
    public var type: FlagValueType
    public var defaultValue: T
    public var ctx: EvaluationContext?
    public var clientMetadata: ClientMetadata?
    public var providerMetadata: ProviderMetadata?
}
