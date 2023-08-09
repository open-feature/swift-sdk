import Foundation

/// This is a common interface between the evaluation results that providers return and what is given to the end users.
/// ``ValueType`` is the type of flag being evaluated.
public protocol BaseEvaluation {
    associatedtype ValueType
    var value: ValueType { get }
    var variant: String? { get }
    var reason: String? { get }
    var errorCode: ErrorCode? { get }
    var errorMessage: String? { get }
}
