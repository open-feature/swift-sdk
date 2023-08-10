import Foundation

/// The ``MutableContext`` is an ``EvaluationContext`` implementation which is not threadsafe, and whose attributes can
/// be modified after instantiation.
public class MutableContext: EvaluationContext {
    private var targetingKey: String
    private var structure: MutableStructure

    public init(targetingKey: String = "", structure: MutableStructure = MutableStructure()) {
        self.targetingKey = targetingKey
        self.structure = structure
    }

    public convenience init(attributes: [String: Value]) {
        self.init(structure: MutableStructure(attributes: attributes))
    }

    public func getTargetingKey() -> String {
        return self.targetingKey
    }

    public func setTargetingKey(targetingKey: String) {
        self.targetingKey = targetingKey
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

extension MutableContext {
    @discardableResult
    public func add(key: String, value: Value) -> MutableContext {
        self.structure.add(key: key, value: value)
        return self
    }
}
