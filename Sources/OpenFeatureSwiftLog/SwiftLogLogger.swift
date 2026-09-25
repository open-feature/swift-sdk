import Foundation
import Logging

// When built as a CocoaPods subspec this file is compiled into the `OpenFeature` module itself,
// so the import is only needed (and only valid) under Swift Package Manager.
#if SWIFT_PACKAGE
    import OpenFeature
#endif

/// An ``OpenFeatureLogger`` that forwards every message to a
/// [swift-log](https://github.com/apple/swift-log) `Logger`.
///
/// ```swift
/// import Logging
/// import OpenFeature
/// import OpenFeatureSwiftLog  // Swift Package Manager only, see below
///
/// let logger = Logger(label: "com.example.app.openfeature")
/// OpenFeatureAPI.shared.setLogger(SwiftLogLogger(logger))
/// ```
///
/// With Swift Package Manager this type lives in the separate `OpenFeatureSwiftLog` product.
/// With CocoaPods (`pod 'OpenFeature/SwiftLog'`) it is compiled into the `OpenFeature` module
/// itself, so omit `import OpenFeatureSwiftLog` and import only `OpenFeature`.
public struct SwiftLogLogger: OpenFeatureLogger {
    /// The underlying swift-log logger.
    public let logger: Logging.Logger

    /// Wraps an existing swift-log logger.
    public init(_ logger: Logging.Logger) {
        self.logger = logger
    }

    /// Creates a swift-log logger with the given label and wraps it.
    public init(label: String) {
        self.logger = Logging.Logger(label: label)
    }

    /// Forwards `message` to the wrapped logger at `.debug` level.
    ///
    /// The message is only evaluated if the wrapped logger's level allows `.debug`.
    public func debug(_ message: @autoclosure () -> String) {
        logger.debug("\(message())")
    }

    /// Forwards `message` to the wrapped logger at `.info` level.
    ///
    /// The message is only evaluated if the wrapped logger's level allows `.info`.
    public func info(_ message: @autoclosure () -> String) {
        logger.info("\(message())")
    }

    /// Forwards `message` to the wrapped logger at `.warning` level.
    ///
    /// The message is only evaluated if the wrapped logger's level allows `.warning`.
    public func warning(_ message: @autoclosure () -> String) {
        logger.warning("\(message())")
    }

    /// Forwards `message` to the wrapped logger at `.error` level.
    ///
    /// The message is only evaluated if the wrapped logger's level allows `.error`.
    public func error(_ message: @autoclosure () -> String) {
        logger.error("\(message())")
    }
}
