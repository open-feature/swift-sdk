import Foundation

/// Values serve as a generic return type for structure data from providers.
/// Providers may deal in JSON, protobuf, XML or some other data-interchange format.
/// This intermediate representation provides a good medium of exchange.
public enum Value: Equatable, Codable {
    case boolean(Bool)
    case string(String)
    case integer(Int64)
    case double(Double)
    case date(Date)
    case list([Value])
    case structure([String: Value])
    case null

    public static func of<T>(_ value: T) -> Value {
        if let value = value as? Bool {
            return .boolean(value)
        } else if let value = value as? String {
            return .string(value)
        } else if let value = value as? Int64 {
            return .integer(value)
        } else if let value = value as? Double {
            return .double(value)
        } else if let value = value as? Date {
            return .date(value)
        } else {
            return .null
        }
    }

    public func getTyped<T>() -> T? {
        if let value = self as? T {
            return value
        }

        switch self {
        case .boolean(let value): return value as? T
        case .string(let value): return value as? T
        case .integer(let value): return value as? T
        case .double(let value): return value as? T
        case .date(let value): return value as? T
        case .list(let value): return value as? T
        case .structure(let value): return value as? T
        case .null: return nil
        }
    }

    public func asBoolean() -> Bool? {
        if case let .boolean(bool) = self {
            return bool
        }

        return nil
    }

    public func asString() -> String? {
        if case let .string(string) = self {
            return string
        }

        return nil
    }

    public func asInteger() -> Int64? {
        if case let .integer(int64) = self {
            return int64
        }

        return nil
    }

    public func asDouble() -> Double? {
        if case let .double(double) = self {
            return double
        }

        return nil
    }

    public func asDate() -> Date? {
        if case let .date(date) = self {
            return date
        }

        return nil
    }

    public func asList() -> [Value]? {
        if case let .list(values) = self {
            return values
        }

        return nil
    }

    public func asStructure() -> [String: Value]? {
        if case let .structure(values) = self {
            return values
        }

        return nil
    }

    public func isNull() -> Bool {
        if case .null = self {
            return true
        }

        return false
    }
}

extension Value: CustomStringConvertible {
    public var description: String {
        switch self {
        case .boolean(let value):
            return "\(value)"
        case .string(let value):
            return value
        case .integer(let value):
            return "\(value)"
        case .double(let value):
            return "\(value)"
        case .date(let value):
            return "\(value)"
        case .list(value: let values):
            return "\(values.map { value in value.description })"
        case .structure(value: let values):
            return "\(values.mapValues { value in value.description })"
        case .null:
            return "null"
        }
    }
}

extension Value {
    public func decode<T: Decodable>() throws -> T {
        let data = try JSONSerialization.data(withJSONObject: toJson(value: self))
        return try JSONDecoder().decode(T.self, from: data)
    }

    func toJson(value: Value) -> Any {
        switch value {
        case .boolean(let bool):
            return bool
        case .string(let string):
            return string
        case .integer(let int64):
            return int64
        case .double(let double):
            return double
        case .date(let date):
            return date.timeIntervalSinceReferenceDate
        case .list(let list):
            return list.map(self.toJson)
        case .structure(let structure):
            return structure.mapValues(self.toJson)
        case .null:
            return NSNull()
        }
    }
}
