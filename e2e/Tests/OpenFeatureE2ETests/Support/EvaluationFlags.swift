import Foundation
import OpenFeature

/// The flags `evaluation.feature` expects. Do not tidy these values -- the Gherkin asserts the
/// literals.
enum EvaluationFlags {
    /// `customer` is a boolean, not the string the Gherkin quotes. See `GherkinArguments.boolOrString`.
    private static let expectedContext: [String: Value] = [
        "fn": .string("Sulisław"),
        "ln": .string("Świętopełk"),
        "age": .integer(29),
        "customer": .boolean(false),
    ]

    private static let contextAwareEvaluator: InMemoryFlag.ContextEvaluator = { _, context in
        let matched = expectedContext.allSatisfy { key, expected in
            context?.getValue(key: key) == expected
        }
        return matched ? "internal" : nil
    }

    static let all: [String: InMemoryFlag] = [
        "boolean-flag": InMemoryFlag(
            variants: ["on": .boolean(true), "off": .boolean(false)],
            defaultVariant: "on"),
        "string-flag": InMemoryFlag(
            variants: ["greeting": .string("hi"), "parting": .string("bye")],
            defaultVariant: "greeting"),
        "integer-flag": InMemoryFlag(
            variants: ["one": .integer(1), "ten": .integer(10)],
            defaultVariant: "ten"),
        "float-flag": InMemoryFlag(
            variants: ["tenth": .double(0.1), "half": .double(0.5)],
            defaultVariant: "half"),
        "object-flag": InMemoryFlag(
            variants: [
                "empty": .structure([:]),
                "template": .structure([
                    "showImages": .boolean(true),
                    "title": .string("Check out these pics!"),
                    "imagesPerPage": .integer(100),
                ]),
            ],
            defaultVariant: "template"),
        // Deliberately a string flag: the "Type error" scenario evaluates it as an integer.
        "wrong-flag": InMemoryFlag(
            variants: ["one": .string("uno"), "two": .string("dos")],
            defaultVariant: "one"),
        "context-aware": InMemoryFlag(
            variants: ["internal": .string("INTERNAL"), "external": .string("EXTERNAL")],
            defaultVariant: "external",
            contextEvaluator: contextAwareEvaluator),
    ]
}
