import Foundation

/// Represents a potentially nested object type which is used to represent
/// structured data.
public protocol Structure {
    func keySet() -> Set<String>
    func getValue(key: String) -> Value?
    func asMap() -> [String: Value]
    func asObjectMap() -> [String: AnyHashable?]
}
