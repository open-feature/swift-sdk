// swiftlint:disable line_length
// swift-format-ignore-file

/// Every step in `spec/specification/assets/gherkin/evaluation.feature`.
///
/// Patterns must stay `^...$`-anchored: CucumberSwift matches unanchored and lets the last match
/// win, so `a flag with key "..."` would otherwise also claim `a boolean flag with key "..."`.
enum EvaluationPatterns {
    // Background
    static let stableProvider = #"^a stable provider$"#

    // Basic evaluation
    static let booleanValue        = #"^a boolean flag with key "([^"]*)" is evaluated with default value "([^"]*)"$"#
    static let booleanValueResult  = #"^the resolved boolean value should be "([^"]*)"$"#
    static let stringValue         = #"^a string flag with key "([^"]*)" is evaluated with default value "([^"]*)"$"#
    static let stringValueResult   = #"^the resolved string value should be "([^"]*)"$"#
    static let integerValue        = #"^an integer flag with key "([^"]*)" is evaluated with default value (-?\d+)$"#
    static let integerValueResult  = #"^the resolved integer value should be (-?\d+)$"#
    static let floatValue          = #"^a float flag with key "([^"]*)" is evaluated with default value (-?\d+\.\d+)$"#
    static let floatValueResult    = #"^the resolved float value should be (-?\d+\.\d+)$"#
    static let objectValue         = #"^an object flag with key "([^"]*)" is evaluated with a null default value$"#
    static let objectValueResult   = #"^the resolved object value should be contain fields "([^"]*)", "([^"]*)", and "([^"]*)", with values "([^"]*)", "([^"]*)" and (-?\d+), respectively$"#

    // Detailed evaluation
    static let booleanDetails       = #"^a boolean flag with key "([^"]*)" is evaluated with details and default value "([^"]*)"$"#
    static let booleanDetailsResult = #"^the resolved boolean details value should be "([^"]*)", the variant should be "([^"]*)", and the reason should be "([^"]*)"$"#
    static let stringDetails        = #"^a string flag with key "([^"]*)" is evaluated with details and default value "([^"]*)"$"#
    static let stringDetailsResult  = #"^the resolved string details value should be "([^"]*)", the variant should be "([^"]*)", and the reason should be "([^"]*)"$"#
    static let integerDetails       = #"^an integer flag with key "([^"]*)" is evaluated with details and default value (-?\d+)$"#
    static let integerDetailsResult = #"^the resolved integer details value should be (-?\d+), the variant should be "([^"]*)", and the reason should be "([^"]*)"$"#
    static let floatDetails         = #"^a float flag with key "([^"]*)" is evaluated with details and default value (-?\d+\.\d+)$"#
    static let floatDetailsResult   = #"^the resolved float details value should be (-?\d+\.\d+), the variant should be "([^"]*)", and the reason should be "([^"]*)"$"#
    static let objectDetails        = #"^an object flag with key "([^"]*)" is evaluated with details and a null default value$"#
    static let objectDetailsResult  = #"^the resolved object details value should be contain fields "([^"]*)", "([^"]*)", and "([^"]*)", with values "([^"]*)", "([^"]*)" and (-?\d+), respectively$"#
    static let variantAndReason     = #"^the variant should be "([^"]*)", and the reason should be "([^"]*)"$"#

    // Context-aware evaluation
    static let contextContainsKeys  = #"^context contains keys "([^"]*)", "([^"]*)", "([^"]*)", "([^"]*)" with values "([^"]*)", "([^"]*)", (-?\d+), "([^"]*)"$"#
    static let untypedFlagValue     = #"^a flag with key "([^"]*)" is evaluated with default value "([^"]*)"$"#
    static let stringResponse       = #"^the resolved string response should be "([^"]*)"$"#
    static let emptyContextValue    = #"^the resolved flag value is "([^"]*)" when the context is empty$"#

    // Errors
    static let missingFlagDetails   = #"^a non-existent string flag with key "([^"]*)" is evaluated with details and a fallback value "([^"]*)"$"#
    static let defaultStringResult  = #"^the default string value should be returned$"#
    static let flagNotFoundReason   = #"^the reason should indicate an error and the error code should indicate a missing flag with "([^"]*)"$"#
    static let wrongTypeDetails     = #"^a string flag with key "([^"]*)" is evaluated as an integer, with details and a fallback value (-?\d+)$"#
    static let defaultIntegerResult = #"^the default integer value should be returned$"#
    static let typeMismatchReason   = #"^the reason should indicate an error and the error code should indicate a type mismatch with "([^"]*)"$"#
}
// swiftlint:enable line_length
