import Foundation

/// An OpenTelemetry-compatible description of one flag evaluation.
///
/// Built by ``Telemetry/createEvaluationEvent(hookContext:evaluationDetails:)``. Emit it from a hook's `finally`
/// stage as a span event or a log record, using ``name`` as the event name and ``attributes`` as its attributes.
public struct EvaluationEvent: Equatable {
    /// The event name; ``Telemetry/evaluationEventName`` for events created by the SDK.
    public let name: String
    /// The event attributes, keyed by the names in ``Telemetry/Attribute``. Every value is an OpenTelemetry
    /// primitive; object and list flag values are carried as JSON strings.
    public let attributes: TelemetryAttributes

    public init(name: String, attributes: TelemetryAttributes) {
        self.name = name
        self.attributes = attributes
    }
}
