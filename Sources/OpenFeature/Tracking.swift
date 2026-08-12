import Foundation

/// Interface for tracking events on static-context client SDKs.
///
/// Evaluation context is read from the stored client context (set via provider initialization or
/// ``OpenFeatureAPI/setEvaluationContext(evaluationContext:)``), not passed at track invocation time.
public protocol Tracking {
    /// Performs tracking of a particular action or application state.
    /// - Parameter key: Event name to track
    func track(key: String)
    /// Performs tracking of a particular action or application state.
    /// - Parameters:
    ///   - key: Event name to track
    ///   - details: Data pertinent to a particular tracking event
    func track(key: String, details: any TrackingEventDetails)
}
