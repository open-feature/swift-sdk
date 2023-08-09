import Foundation

/// The ``MutableStructure`` is a ``Structure`` implementation which is not threadsafe, and whose attributes can
/// be modified after instantiation.
public class MutableStructure: Structure {
    private var attributes: [String: Value]

    public init(attributes: [String: Value] = [:]) {
        self.attributes = attributes
    }

    public func keySet() -> Set<String> {
        return Set(attributes.keys)
    }

    public func getValue(key: String) -> Value? {
        return attributes[key]
    }

    public func asMap() -> [String: Value] {
        return attributes
    }

    public func asObjectMap() -> [String: AnyHashable?] {
        return attributes.mapValues(convertValue)
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
        attributes[key] = value
        return self
    }
}
