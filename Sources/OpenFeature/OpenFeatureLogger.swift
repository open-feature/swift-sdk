import Foundation

/// A minimal logging abstraction used by the OpenFeature SDK.
///
/// The SDK does not depend on any logging framework. Conform your own logger to this
/// protocol and pass it to ``OpenFeatureAPI/setLogger(_:)``, ``Client/setLogger(_:)`` or
/// ``FlagEvaluationOptions/init(hooks:hookHints:logger:)``. The same instance is handed to
/// providers during flag evaluation.
///
/// Messages are passed as autoclosures so that string interpolation is only evaluated when the
/// implementation actually emits the message.
///
/// Implementations may be called from any thread and must be thread-safe.
///
/// A ready-made conformance for [swift-log](https://github.com/apple/swift-log) is available in
/// the optional `OpenFeatureSwiftLog` product.
public protocol OpenFeatureLogger {
    /// Logs a message at debug level.
    func debug(_ message: @autoclosure () -> String)

    /// Logs a message at info level.
    func info(_ message: @autoclosure () -> String)

    /// Logs a message at warning level.
    func warning(_ message: @autoclosure () -> String)

    /// Logs a message at error level.
    func error(_ message: @autoclosure () -> String)
}
