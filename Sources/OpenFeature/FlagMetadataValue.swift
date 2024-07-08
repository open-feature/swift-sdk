import Foundation

public enum FlagMetadataValue: Equatable, Codable {
    case boolean(Bool)
    case string(String)
    case integer(Int64)
    case double(Double)

    public static func of<T>(_ value: T) -> FlagMetadataValue? {
        if let value = value as? Bool {
            return .boolean(value)
        } else if let value = value as? String {
            return .string(value)
        } else if let value = value as? Int64 {
            return .integer(value)
        } else if let value = value as? Double {
            return .double(value)
        } else {
            return nil
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
}

extension FlagMetadataValue: CustomStringConvertible {
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
        }
    }
}

extension FlagMetadataValue {
    public func decode<T: Decodable>() throws -> T {
        let data = try JSONSerialization.data(withJSONObject: toJson(value: self))
        return try JSONDecoder().decode(T.self, from: data)
    }

    func toJson(value: FlagMetadataValue) -> Any {
        switch value {
        case .boolean(let bool):
            return bool
        case .string(let string):
            return string
        case .integer(let int64):
            return int64
        case .double(let double):
            return double
        }
    }
}
