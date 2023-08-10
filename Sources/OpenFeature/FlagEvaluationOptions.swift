import Foundation

public struct FlagEvaluationOptions {
    var hooks: [any Hook] = []
    var hookHints: [String: Any] = [:]
}
