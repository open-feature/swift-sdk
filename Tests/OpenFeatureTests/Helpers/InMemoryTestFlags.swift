import Foundation
import OpenFeature

/// Flag configuration shared by the `InMemoryProvider` test cases.
enum InMemoryTestFlags {
    static let templateVariant: Value = .structure([
        "showImages": .boolean(true),
        "title": .string("Check out these pics!"),
        "imagesPerPage": .integer(100),
    ])

    static let metadata: FlagMetadata = [
        "string": .string("1.0.2"),
        "integer": .integer(2),
        "boolean": .boolean(true),
        "double": .double(0.1),
    ]

    static let contextAwareEvaluator: InMemoryFlag.ContextEvaluator = { _, context in
        context?.getValue(key: "customer") == .boolean(false) ? "internal" : nil
    }

    static func all() -> [String: InMemoryFlag] {
        return [
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
                variants: ["empty": .structure([:]), "template": templateVariant],
                defaultVariant: "template"),
            "metadata-flag": InMemoryFlag(
                variants: ["on": .boolean(true), "off": .boolean(false)],
                defaultVariant: "on",
                flagMetadata: metadata),
            "disabled-flag": InMemoryFlag(
                variants: ["on": .boolean(true), "off": .boolean(false)],
                defaultVariant: "on",
                flagMetadata: metadata,
                disabled: true),
            "missing-variant-flag": InMemoryFlag(
                variants: ["on": .boolean(true)],
                defaultVariant: "nope"),
            "context-aware": InMemoryFlag(
                variants: ["internal": .string("INTERNAL"), "external": .string("EXTERNAL")],
                defaultVariant: "external",
                contextEvaluator: contextAwareEvaluator),
        ]
    }

    static func single(key: String) -> [String: InMemoryFlag] {
        return [key: InMemoryFlag(variants: ["on": .boolean(true)], defaultVariant: "on")]
    }

    static func enabledFlag() -> InMemoryFlag {
        return InMemoryFlag(variants: ["on": .boolean(true)], defaultVariant: "on")
    }

    /// Already through `initialize`, without going through `OpenFeatureAPI`.
    static func readyProvider(flags: [String: InMemoryFlag]? = nil) -> InMemoryProvider {
        let provider = InMemoryProvider(flags: flags ?? all())
        _ = provider.initialize(initialContext: nil)
        return provider
    }

    static func internalCustomerContext() -> MutableContext {
        return MutableContext(targetingKey: "user-1").add(key: "customer", value: .boolean(false))
    }
}
