import Foundation

/// A hook that logs the stages of every flag evaluation it runs for through an ``OpenFeatureLogger``, as described by
/// the logging hook of Appendix A of the OpenFeature specification.
///
/// | Stage     | Level | Logged data                                                                           |
/// |-----------|-------|---------------------------------------------------------------------------------------|
/// | `before`  | debug | `stage`, `domain`, `provider_name`, `flag_key`, `default_value`, `evaluation_context` |
/// | `after`   | debug | the `before` data, plus `reason`, `variant` and `value`                               |
/// | `error`   | error | the `before` data, plus `error_code` and `error_message`                              |
/// | `finally` | —     | nothing                                                                               |
///
/// Each stage is logged as a single line of `key=value` pairs, where every value is written as JSON so that strings,
/// numbers and nested objects stay unambiguous, for example:
///
/// ```
/// stage="before" domain="checkout" provider_name="InMemoryProvider" flag_key="new-checkout" default_value=false
/// ```
///
/// `domain` is the name of the client that ran the evaluation. Data the evaluation does not have, such as the domain
/// of an unnamed client or the variant of a value resolved without one, is left out.
///
/// The evaluation context may contain personal data, so `evaluation_context` is only logged when the hook is created
/// with `includeEvaluationContext: true`.
///
/// ```swift
/// OpenFeatureAPI.shared.addHooks(hooks: LoggingHook(logger: OSLogOpenFeatureLogger()))
/// ```
///
/// - SeeAlso: https://openfeature.dev/specification/appendix-a#logging-hook
public struct LoggingHook: Hook {
    public typealias HookValue = Value

    private let logger: any OpenFeatureLogger
    private let includeEvaluationContext: Bool

    /// Creates a logging hook.
    /// - Parameters:
    ///   - logger: The logger the stages are written to.
    ///   - includeEvaluationContext: Whether to log the evaluation context. Defaults to `false`, because the context
    ///     may contain personal data.
    public init(logger: any OpenFeatureLogger, includeEvaluationContext: Bool = false) {
        self.logger = logger
        self.includeEvaluationContext = includeEvaluationContext
    }

    /// Runs for every flag value type.
    public func supportsFlagValueType(flagValueType: FlagValueType) -> Bool {
        true
    }

    public func before<HookValue>(ctx: HookContext<HookValue>, hints: [String: Any]) {
        logger.debug(message(stage: "before", ctx: ctx))
    }

    public func after<HookValue>(
        ctx: HookContext<HookValue>, details: FlagEvaluationDetails<HookValue>, hints: [String: Any]
    ) {
        logger.debug(
            message(
                stage: "after",
                ctx: ctx,
                fields: [
                    ("reason", details.reason.map(quoted)),
                    ("variant", details.variant.map(quoted)),
                    ("value", json(flagValue: details.value)),
                ]))
    }

    public func error<HookValue>(ctx: HookContext<HookValue>, error: Error, hints: [String: Any]) {
        let errorCode = (error as? OpenFeatureError)?.errorCode() ?? .general
        logger.error(
            message(
                stage: "error",
                ctx: ctx,
                fields: [
                    ("error_code", quoted(name(of: errorCode))),
                    ("error_message", quoted("\(error)")),
                ]))
    }

    // MARK: - Formatting

    /// Builds the log line of a stage: the data shared by all stages, followed by the stage-specific `fields`.
    /// Fields without a value are left out.
    private func message<T>(
        stage: String,
        ctx: HookContext<T>,
        fields: [(key: String, value: String?)] = []
    ) -> String {
        var common: [(key: String, value: String?)] = [
            ("stage", quoted(stage)),
            ("domain", ctx.clientMetadata?.name.map(quoted)),
            ("provider_name", ctx.providerMetadata?.name.map(quoted)),
            ("flag_key", quoted(ctx.flagKey)),
            ("default_value", json(flagValue: ctx.defaultValue)),
        ]
        if includeEvaluationContext {
            common.append(("evaluation_context", ctx.ctx.map(json(context:))))
        }
        return (common + fields)
            .compactMap { field in field.value.map { "\(field.key)=\($0)" } }
            .joined(separator: " ")
    }

    /// Renders the evaluation context as a JSON object holding its targeting key and its attributes.
    private func json(context: EvaluationContext) -> String {
        json(
            Value.structure([
                "targetingKey": .string(context.getTargetingKey()),
                "attributes": .structure(context.asMap()),
            ]))
    }

    /// Renders a flag value of any of the types the SDK evaluates.
    private func json<T>(flagValue: T) -> String {
        if let value = flagValue as? Value {
            return json(value)
        }
        return json(Value.of(flagValue))
    }

    /// Renders a value as JSON, with object keys sorted so that equal values always produce the same text. Dates are
    /// written as ISO 8601 strings. Non-finite doubles, which JSON cannot represent, are written as `nan`, `inf` or
    /// `-inf`.
    private func json(_ value: Value) -> String {
        switch value {
        case .boolean(let bool):
            return "\(bool)"
        case .string(let string):
            return quoted(string)
        case .integer(let integer):
            return "\(integer)"
        case .double(let double):
            return "\(double)"
        case .date(let date):
            return quoted(Self.iso8601Formatter.string(from: date))
        case .list(let list):
            return "[" + list.map(json).joined(separator: ",") + "]"
        case .structure(let structure):
            let members = structure.sorted { $0.key < $1.key }.map { "\(quoted($0.key)):\(json($0.value))" }
            return "{" + members.joined(separator: ",") + "}"
        case .null:
            return "null"
        }
    }

    /// Writes a string as a JSON string literal, quoted and escaped.
    private func quoted(_ string: String) -> String {
        guard let data = try? Self.jsonEncoder.encode(string), let literal = String(data: data, encoding: .utf8) else {
            return "\"\(string)\""
        }
        return literal
    }

    /// The error code's name in the specification, for example `FLAG_NOT_FOUND`.
    private func name(of errorCode: ErrorCode) -> String {
        switch errorCode {
        case .providerNotReady:
            return "PROVIDER_NOT_READY"
        case .flagNotFound:
            return "FLAG_NOT_FOUND"
        case .parseError:
            return "PARSE_ERROR"
        case .typeMismatch:
            return "TYPE_MISMATCH"
        case .targetingKeyMissing:
            return "TARGETING_KEY_MISSING"
        case .invalidContext:
            return "INVALID_CONTEXT"
        case .general:
            return "GENERAL"
        case .providerFatal:
            return "PROVIDER_FATAL"
        }
    }

    private static let jsonEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.withoutEscapingSlashes]
        return encoder
    }()

    private static let iso8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}
