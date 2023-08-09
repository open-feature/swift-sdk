import Foundation

public protocol AllowedFlagValueType: Equatable {
    static var flagValueType: FlagValueType { get }
}

extension Bool: AllowedFlagValueType {
    public static var flagValueType: FlagValueType { .boolean }
}

extension Int64: AllowedFlagValueType {
    public static var flagValueType: FlagValueType { .integer }
}

extension Double: AllowedFlagValueType {
    public static var flagValueType: FlagValueType { .double }
}

extension String: AllowedFlagValueType {
    public static var flagValueType: FlagValueType { .string }
}

extension Value: AllowedFlagValueType {
    public static var flagValueType: FlagValueType { .object }
}

public enum FlagValueType {
    case string
    case integer
    case double
    case object
    case boolean
}
