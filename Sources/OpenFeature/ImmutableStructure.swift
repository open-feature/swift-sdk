import Foundation

/// The ``ImmutableStructure`` is a ``Structure`` implementation which is immutable and thread-safe.
/// It provides read-only access to structured data and cannot be modified after creation.
public class ImmutableStructure: Structure {
    private let attributes: [String: Value]

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

    public func deepCopy() -> ImmutableStructure {
        return ImmutableStructure(attributes: attributes)
    }
}

extension ImmutableStructure {
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
