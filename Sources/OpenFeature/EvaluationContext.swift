import Foundation

/// Container for arbitrary contextual data that can be used as a basis for dynamic evaluation.
public protocol EvaluationContext: Structure {
    func getTargetingKey() -> String

    func setTargetingKey(targetingKey: String)
}
