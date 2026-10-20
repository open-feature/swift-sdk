import Foundation

/// The attributes of an ``EvaluationEvent``, keyed by the names in ``Telemetry/Attribute``.
public typealias TelemetryAttributes = [String: TelemetryAttributeValue]

/// An attribute value of an ``EvaluationEvent``: a boolean, string, integer or double, the primitives that
/// OpenTelemetry attributes support.
public typealias TelemetryAttributeValue = MetadataValue
