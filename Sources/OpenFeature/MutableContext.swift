import Foundation

/// The ``MutableContext`` is an ``EvaluationContext`` implementation which is threadsafe, and whose attributes can
/// be modified after instantiation.
public class MutableContext: EvaluationContext {
    private let queue = DispatchQueue(label: "com.openfeature.mutablecontext.queue", qos: .userInitiated)
    private var targetingKey: String
    private var structure: MutableStructure

    public init(targetingKey: String = "", structure: MutableStructure = MutableStructure()) {
        self.targetingKey = targetingKey
        self.structure = structure
    }

    public convenience init(attributes: [String: Value]) {
        self.init(structure: MutableStructure(attributes: attributes))
    }

    public func deepCopy() -> EvaluationContext {
        return queue.sync {
            MutableContext(targetingKey: targetingKey, structure: structure.deepCopy())
        }
    }

    public func getTargetingKey() -> String {
        return queue.sync {
            self.targetingKey
        }
    }

    public func setTargetingKey(targetingKey: String) {
        queue.sync {
            self.targetingKey = targetingKey
        }
    }

    public func keySet() -> Set<String> {
        return queue.sync {
            structure.keySet()
        }
    }

    public func getValue(key: String) -> Value? {
        return queue.sync {
            structure.getValue(key: key)
        }
    }

    public func asMap() -> [String: Value] {
        return queue.sync {
            structure.asMap()
        }
    }

    public func asObjectMap() -> [String: AnyHashable?] {
        return queue.sync {
            structure.asObjectMap()
        }
    }
}

extension MutableContext {
    @discardableResult
    public func add(key: String, value: Value) -> MutableContext {
        queue.sync {
            self.structure.add(key: key, value: value)
        }
        return self
    }
}
