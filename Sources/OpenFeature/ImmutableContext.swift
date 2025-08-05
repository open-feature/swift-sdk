import Foundation

/// The ``ImmutableContext`` is an ``EvaluationContext`` implementation which is immutable and thread-safe.
/// It provides read-only access to context data and cannot be modified after creation.
public struct ImmutableContext: EvaluationContext {
    private let targetingKey: String
    private let structure: ImmutableStructure

    public init(targetingKey: String = "", structure: ImmutableStructure = ImmutableStructure()) {
        self.targetingKey = targetingKey
        self.structure = structure
    }

    public init(attributes: [String: Value]) {
        self.init(structure: ImmutableStructure(attributes: attributes))
    }

    public func deepCopy() -> EvaluationContext {
        return ImmutableContext(targetingKey: targetingKey, structure: structure.deepCopy())
    }

    public func getTargetingKey() -> String {
        return targetingKey
    }

    public func keySet() -> Set<String> {
        return structure.keySet()
    }

    public func getValue(key: String) -> Value? {
        return structure.getValue(key: key)
    }

    public func asMap() -> [String: Value] {
        return structure.asMap()
    }

    public func asObjectMap() -> [String: AnyHashable?] {
        return structure.asObjectMap()
    }
}

extension ImmutableContext {
    /// Creates an immutable context from a mutable context
    public init(from mutableContext: MutableContext) {
        self.init(
            targetingKey: mutableContext.getTargetingKey(),
            structure: ImmutableStructure(attributes: mutableContext.asMap())
        )
    }
}
