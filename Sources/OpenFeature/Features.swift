import Foundation

/// An API for the type-specific fetch methods offered to users.
public protocol Features {
    // MARK: Generics
    func getValue<T: AllowedFlagValueType>(key: String, defaultValue: T) -> T

    func getValue<T: AllowedFlagValueType>(
        key: String, defaultValue: T, options: FlagEvaluationOptions
    ) -> T

    func getDetails<T: AllowedFlagValueType>(key: String, defaultValue: T) -> FlagEvaluationDetails<T>

    func getDetails<T: AllowedFlagValueType>(
        key: String, defaultValue: T, options: FlagEvaluationOptions
    ) -> FlagEvaluationDetails<T>

    // MARK: Bool
    func getBooleanValue(key: String, defaultValue: Bool) -> Bool

    func getBooleanValue(key: String, defaultValue: Bool, options: FlagEvaluationOptions)
        -> Bool

    func getBooleanDetails(key: String, defaultValue: Bool) -> FlagEvaluationDetails<Bool>

    func getBooleanDetails(
        key: String, defaultValue: Bool, options: FlagEvaluationOptions
    ) -> FlagEvaluationDetails<Bool>

    // MARK: String
    func getStringValue(key: String, defaultValue: String) -> String

    func getStringValue(key: String, defaultValue: String, options: FlagEvaluationOptions)
        -> String

    func getStringDetails(key: String, defaultValue: String) -> FlagEvaluationDetails<String>

    func getStringDetails(
        key: String, defaultValue: String, options: FlagEvaluationOptions
    ) -> FlagEvaluationDetails<String>

    // MARK: Int
    func getIntegerValue(key: String, defaultValue: Int64) -> Int64

    func getIntegerValue(key: String, defaultValue: Int64, options: FlagEvaluationOptions)
        -> Int64

    func getIntegerDetails(key: String, defaultValue: Int64) -> FlagEvaluationDetails<Int64>

    func getIntegerDetails(
        key: String, defaultValue: Int64, options: FlagEvaluationOptions
    ) -> FlagEvaluationDetails<Int64>

    // MARK: Double
    func getDoubleValue(key: String, defaultValue: Double) -> Double

    func getDoubleValue(key: String, defaultValue: Double, options: FlagEvaluationOptions)
        -> Double

    func getDoubleDetails(key: String, defaultValue: Double) -> FlagEvaluationDetails<Double>

    func getDoubleDetails(
        key: String, defaultValue: Double, options: FlagEvaluationOptions
    ) -> FlagEvaluationDetails<Double>

    // MARK: Object
    func getObjectValue(key: String, defaultValue: Value) -> Value

    func getObjectValue(key: String, defaultValue: Value, options: FlagEvaluationOptions)
        -> Value

    func getObjectDetails(key: String, defaultValue: Value) -> FlagEvaluationDetails<Value>

    func getObjectDetails(
        key: String, defaultValue: Value, options: FlagEvaluationOptions
    ) -> FlagEvaluationDetails<Value>
}
