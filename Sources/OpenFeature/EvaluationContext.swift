import Foundation

/// Container for arbitrary contextual data that can be used as a basis for dynamic evaluation.
public protocol EvaluationContext: Structure {
    func getTargetingKey() -> String
    func deepCopy() -> EvaluationContext
    func setTargetingKey(targetingKey: String)
}
