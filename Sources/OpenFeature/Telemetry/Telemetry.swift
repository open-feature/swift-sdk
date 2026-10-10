import Foundation

/// Builds OpenTelemetry-compatible telemetry from flag evaluations, following Appendix D (Observability) of the
/// OpenFeature specification and the OpenTelemetry feature-flag semantic conventions.
///
/// Call ``createEvaluationEvent(hookContext:evaluationDetails:)`` from a hook's `finally` stage, where the
/// evaluation details are complete, and hand the resulting ``EvaluationEvent`` to your exporter as a span event or a
/// log record. The utility has no configuration and no dependencies: dropping or truncating attributes, for example
/// ``Attribute/value`` when flag values may be sensitive, is the hook's job.
///
/// - SeeAlso: https://openfeature.dev/specification/appendix-d
public enum Telemetry {
    /// The name of the evaluation event: `feature_flag.evaluation`.
    public static let evaluationEventName = "feature_flag.evaluation"

    /// Attribute names of an OpenTelemetry feature-flag evaluation event.
    ///
    /// - SeeAlso: https://opentelemetry.io/docs/specs/semconv/feature-flags/feature-flags-logs/
    public enum Attribute {
        /// The lookup key of the feature flag. Always present.
        public static let flagKey = "feature_flag.key"
        /// The name of the provider that resolved the flag. Present when the provider reports a name.
        public static let providerName = "feature_flag.provider.name"
        /// How the value was determined, in lowercase, for example `targeting_match`. Always present; `unknown` when
        /// the provider gave no reason.
        public static let reason = "feature_flag.result.reason"
        /// The symbolic name of the resolved value, for example `on`. Present when the provider supplied a variant.
        public static let variant = "feature_flag.result.variant"
        /// The resolved value. Primitive values are carried as they are; object and list values as a JSON string.
        public static let value = "feature_flag.result.value"
        /// Identifies the subject of the evaluation: the `contextId` flag metadata, or else the targeting key.
        public static let contextId = "feature_flag.context.id"
        /// The flag set the flag belongs to, from the `flagSetId` flag metadata.
        public static let flagSetId = "feature_flag.set.id"
        /// The version of the flag or flag set, from the `version` flag metadata.
        public static let version = "feature_flag.version"
        /// The error code in lowercase snake_case, for example `flag_not_found`. Present only when the evaluation
        /// failed.
        public static let errorType = "error.type"
        /// A human-readable description of the failure. Present only when the evaluation failed with a message.
        public static let errorMessage = "error.message"
    }

    /// Well-known flag metadata keys through which providers carry telemetry data.
    ///
    /// - SeeAlso: https://openfeature.dev/specification/appendix-d#flag-metadata
    public enum FlagMetadataKey {
        /// Uniquely identifies the subject of the evaluation; mapped to ``Attribute/contextId``.
        public static let contextId = "contextId"
        /// A logical identifier for the flag set; mapped to ``Attribute/flagSetId``.
        public static let flagSetId = "flagSetId"
        /// A version string for the flag or flag set; mapped to ``Attribute/version``.
        public static let version = "version"
    }

    /// Creates the evaluation event for one flag evaluation.
    ///
    /// Intended for the `finally` stage of a hook, where `evaluationDetails` is complete whether the evaluation
    /// succeeded or failed. Attributes without a value are left out rather than set to an empty value.
    ///
    /// - Parameters:
    ///   - hookContext: The hook context of the evaluation.
    ///   - evaluationDetails: The evaluation details handed to the `finally` stage.
    /// - Returns: An event named ``evaluationEventName`` carrying the attributes described in ``Attribute``.
    public static func createEvaluationEvent<T>(
        hookContext: HookContext<T>,
        evaluationDetails: FlagEvaluationDetails<T>
    ) -> EvaluationEvent {
        var attributes: TelemetryAttributes = [:]
        attributes[Attribute.flagKey] = .string(hookContext.flagKey)
        if let providerName = hookContext.providerMetadata?.name {
            attributes[Attribute.providerName] = .string(providerName)
        }
        attributes[Attribute.reason] = .string((evaluationDetails.reason ?? Reason.unknown.rawValue).lowercased())
        if let variant = evaluationDetails.variant {
            attributes[Attribute.variant] = .string(variant)
        }
        if let value = attributeValue(for: evaluationDetails.value) {
            attributes[Attribute.value] = value
        }
        addMetadataAttributes(to: &attributes, metadata: evaluationDetails.flagMetadata, context: hookContext.ctx)
        addErrorAttributes(to: &attributes, evaluationDetails: evaluationDetails)
        return EvaluationEvent(name: evaluationEventName, attributes: attributes)
    }

    // MARK: - Flag metadata

    private static func addMetadataAttributes(
        to attributes: inout TelemetryAttributes,
        metadata: FlagMetadata,
        context: EvaluationContext?
    ) {
        let contextId = metadata[FlagMetadataKey.contextId]?.asString() ?? context?.getTargetingKey()
        if let contextId = contextId, !contextId.isEmpty {
            attributes[Attribute.contextId] = .string(contextId)
        }
        if let flagSetId = metadata[FlagMetadataKey.flagSetId]?.asString() {
            attributes[Attribute.flagSetId] = .string(flagSetId)
        }
        if let version = metadata[FlagMetadataKey.version]?.asString() {
            attributes[Attribute.version] = .string(version)
        }
    }

    // MARK: - Errors

    private static func addErrorAttributes<T>(
        to attributes: inout TelemetryAttributes,
        evaluationDetails: FlagEvaluationDetails<T>
    ) {
        guard evaluationDetails.reason?.uppercased() == Reason.error.rawValue else {
            return
        }
        attributes[Attribute.errorType] = .string(errorType(for: evaluationDetails.errorCode ?? .general))
        if let errorMessage = evaluationDetails.errorMessage {
            attributes[Attribute.errorMessage] = .string(errorMessage)
        }
    }

    /// The error code's specification name in OpenTelemetry's lowercase snake_case form.
    private static func errorType(for errorCode: ErrorCode) -> String {
        switch errorCode {
        case .providerNotReady:
            return "provider_not_ready"
        case .flagNotFound:
            return "flag_not_found"
        case .parseError:
            return "parse_error"
        case .typeMismatch:
            return "type_mismatch"
        case .targetingKeyMissing:
            return "targeting_key_missing"
        case .invalidContext:
            return "invalid_context"
        case .general:
            return "general"
        case .providerFatal:
            return "provider_fatal"
        }
    }

    // MARK: - Values

    /// Maps a flag value to an attribute value, or `nil` when it has no representation: `Value.null`, a value that
    /// cannot be serialised to JSON, or a type the SDK does not evaluate.
    private static func attributeValue(for flagValue: Any) -> TelemetryAttributeValue? {
        switch flagValue {
        case let bool as Bool:
            return .boolean(bool)
        case let string as String:
            return .string(string)
        case let integer as Int64:
            return .integer(integer)
        case let double as Double:
            return .double(double)
        case let value as Value:
            return attributeValue(for: value)
        default:
            return nil
        }
    }

    private static func attributeValue(for value: Value) -> TelemetryAttributeValue? {
        switch value {
        case .boolean(let bool):
            return .boolean(bool)
        case .string(let string):
            return .string(string)
        case .integer(let integer):
            return .integer(integer)
        case .double(let double):
            return .double(double)
        case .date(let date):
            return .string(iso8601(date))
        case .list, .structure:
            return jsonString(for: value).map { .string($0) }
        case .null:
            return nil
        }
    }

    /// Serialises a list or structure to compact JSON with sorted keys, so equal values always produce the same
    /// attribute. Returns `nil` when the value cannot be represented in JSON, such as a non-finite double.
    private static func jsonString(for value: Value) -> String? {
        let object = jsonObject(for: value)
        guard JSONSerialization.isValidJSONObject(object),
            let data = try? JSONSerialization.data(
                withJSONObject: object, options: [.sortedKeys, .withoutEscapingSlashes])
        else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    private static func jsonObject(for value: Value) -> Any {
        switch value {
        case .boolean(let bool):
            return bool
        case .string(let string):
            return string
        case .integer(let integer):
            return integer
        case .double(let double):
            return double
        case .date(let date):
            return iso8601(date)
        case .list(let list):
            return list.map(jsonObject(for:))
        case .structure(let structure):
            return structure.mapValues(jsonObject(for:))
        case .null:
            return NSNull()
        }
    }

    private static let iso8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static func iso8601(_ date: Date) -> String {
        iso8601Formatter.string(from: date)
    }
}
