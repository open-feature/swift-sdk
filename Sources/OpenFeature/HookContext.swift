import Foundation

/// A data struct to hold immutable context that ``Hook`` instances use.
public struct HookContext<T> {
    var flagKey: String
    var type: FlagValueType
    var defaultValue: T
    var ctx: EvaluationContext?
    var clientMetadata: ClientMetadata?
    var providerMetadata: ProviderMetadata?
}
