import Foundation

@testable import OpenFeature

/// Builds the hook contexts and evaluation events the telemetry tests assert on.
enum TelemetryFixtures {
    static let flagKey = "flag-key"
    static let targetingKey = "targeting-key"
    static let providerName = "Provider name"

    struct ProviderMetadataStub: ProviderMetadata {
        var name: String?
    }

    /// A hook context for `flagKey`, evaluated against a context with `targetingKey` (none when `nil`) by a provider
    /// described by `providerMetadata` (none when `nil`).
    static func makeContext<T>(
        flagKey: String = Self.flagKey,
        defaultValue: T,
        targetingKey: String? = Self.targetingKey,
        providerMetadata: ProviderMetadata? = ProviderMetadataStub(name: Self.providerName)
    ) -> HookContext<T> {
        HookContext(
            flagKey: flagKey,
            type: .string,
            defaultValue: defaultValue,
            ctx: targetingKey.map { ImmutableContext(targetingKey: $0) },
            clientMetadata: nil,
            providerMetadata: providerMetadata)
    }

    /// The event for `evaluation`, using the default context unless one is given.
    static func makeEvent<T: Equatable>(
        _ evaluation: ProviderEvaluation<T>,
        context: HookContext<T>? = nil
    ) -> EvaluationEvent {
        Telemetry.createEvaluationEvent(
            hookContext: context ?? makeContext(defaultValue: evaluation.value),
            evaluationDetails: FlagEvaluationDetails.from(providerEval: evaluation, flagKey: flagKey))
    }

    /// The `feature_flag.result.value` attribute produced when an object-typed flag resolves to `value`.
    static func objectValueAttribute(_ value: Value) -> TelemetryAttributeValue? {
        makeEvent(ProviderEvaluation(value: value), context: makeContext(defaultValue: Value.null))
            .attributes[Telemetry.Attribute.value]
    }
}
