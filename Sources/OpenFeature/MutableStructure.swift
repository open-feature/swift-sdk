import Foundation

/// The ``MutableStructure`` is a ``Structure`` implementation which is threadsafe, and whose attributes can
/// be modified after instantiation.
public class MutableStructure: Structure {
    private let queue = DispatchQueue(label: "com.openfeature.mutablestructure.queue", qos: .userInitiated)
    private var attributes: [String: Value]

    public init(attributes: [String: Value] = [:]) {
        self.attributes = attributes
    }

    public func keySet() -> Set<String> {
        return queue.sync {
            Set(attributes.keys)
        }
    }

    public func getValue(key: String) -> Value? {
        return queue.sync {
            attributes[key]
        }
    }

    public func asMap() -> [String: Value] {
        return queue.sync {
            attributes
        }
    }

    public func asObjectMap() -> [String: AnyHashable?] {
        return queue.sync {
            attributes.mapValues(convertValue)
        }
    }

    public func deepCopy() -> MutableStructure {
        return queue.sync {
            MutableStructure(attributes: attributes)
        }
    }
}

extension MutableStructure {
    private func convertValue(value: Value) -> AnyHashable? {
        switch value {
        case .boolean(let value):
            return value
        case .string(let value):
            return value
        case .integer(let value):
            return value
        case .double(let value):
            return value
        case .date(let value):
            return value
        case .list(let value):
            return value.map(convertValue)
        case .structure(let value):
            return value.mapValues(convertValue)
        case .null:
            return nil
        }
    }
}

extension MutableStructure {
    public enum ConversionError: Error {
        case valueNotConvertableError
    }
}

extension MutableStructure {
    @discardableResult
    public func add(key: String, value: Value) -> MutableStructure {
        queue.sync {
            attributes[key] = value
        }
        return self
    }
}
