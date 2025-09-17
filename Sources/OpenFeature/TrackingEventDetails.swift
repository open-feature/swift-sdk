import Foundation

/// Data pertinent to a particular tracking event.
public protocol TrackingEventDetails: Structure {
    /// Get the value from this event.
    /// - Returns: The optional numeric value tracking value.
    func getValue() -> Double?
}
