import Foundation

/// Represents data pertinent to a particular tracking event.
public struct ImmutableTrackingEventDetails: TrackingEventDetails {
    private let value: Double?
    private let structure: ImmutableStructure

    public init(value: Double? = nil, structure: ImmutableStructure = ImmutableStructure()) {
        self.value = value
        self.structure = structure
    }

    public init(attributes: [String: Value]) {
        self.init(structure: ImmutableStructure(attributes: attributes))
    }

    public func getValue() -> Double? {
        value
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

extension ImmutableTrackingEventDetails {
    public func withValue(_ value: Double?) -> ImmutableTrackingEventDetails {
        ImmutableTrackingEventDetails(value: value, structure: structure)
    }

    public func withAttribute(key: String, value: Value) -> ImmutableTrackingEventDetails {
        var newAttributes = structure.asMap()
        newAttributes[key] = value
        return ImmutableTrackingEventDetails(
            value: self.value,
            structure: ImmutableStructure(attributes: newAttributes)
        )
    }

    public func withAttributes(_ attributes: [String: Value]) -> ImmutableTrackingEventDetails {
        let newAttributes = structure.asMap().merging(attributes) { (_, new) in new }
        return ImmutableTrackingEventDetails(
            value: self.value,
            structure: ImmutableStructure(attributes: newAttributes)
        )
    }

    public func withoutAttribute(key: String) -> ImmutableTrackingEventDetails {
        var newAttributes = structure.asMap()
        newAttributes.removeValue(forKey: key)
        return ImmutableTrackingEventDetails(
            value: self.value,
            structure: ImmutableStructure(attributes: newAttributes)
        )
    }
}
