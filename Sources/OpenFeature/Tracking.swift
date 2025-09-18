import Foundation

/// Interface for Tracking events.
public protocol Tracking {
    /// Performs tracking of a particular action or application state.
    /// - Parameter key: Event name to track
    func track(key: String)
    /// Performs tracking of a particular action or application state.
    /// - Parameters:
    ///   - key: Event name to track
    ///   - context: Evaluation context used in flag evaluation
    func track(key: String, context: any EvaluationContext)
    /// Performs tracking of a particular action or application state.
    /// - Parameters:
    ///   - key: Event name to track
    ///   - details: Data pertinent to a particular tracking event
    func track(key: String, details: any TrackingEventDetails)
    /// Performs tracking of a particular action or application state.
    /// - Parameters:
    ///   - key: Event name to track
    ///   - context: Evaluation context used in flag evaluation
    ///   - details: Data pertinent to a particular tracking event
    func track(key: String, context: any EvaluationContext, details: any TrackingEventDetails)
}
