import Foundation

public enum OpenFeatureError: Error, Equatable {
    case flagNotFoundError(key: String)
    case generalError(message: String)
    case invalidContextError
    case parseError(message: String)
    case targetingKeyMissingError
    case typeMismatchError
    case valueNotConvertableError
    case providerNotReadyError
    case providerFatalError(message: String)

    public func errorCode() -> ErrorCode {
        switch self {
        case .flagNotFoundError:
            return .flagNotFound
        case .generalError:
            return .general
        case .invalidContextError:
            return .invalidContext
        case .parseError:
            return .parseError
        case .targetingKeyMissingError:
            return .targetingKeyMissing
        case .typeMismatchError:
            return .typeMismatch
        case .valueNotConvertableError:
            return .general
        case .providerNotReadyError:
            return .providerNotReady
        case .providerFatalError:
            return .providerFatal
        }
    }
}

extension OpenFeatureError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .flagNotFoundError(let key):
            return "Could not find flag for key: \(key)"
        case .generalError(let message):
            return "General error: \(message)"
        case .invalidContextError:
            return "Invalid or missing context"
        case .parseError(let message):
            return "Parse error: \(message)"
        case .targetingKeyMissingError:
            return "Targeting key missing in resolve"
        case .typeMismatchError:
            return "Type mismatch"
        case .valueNotConvertableError:
            return "Could not convert value"
        case .providerNotReadyError:
            return "The value was resolved before the provider was ready"
        case .providerFatalError(let message):
            return "A fatal error occurred in the provider: \(message)"
        }
    }
}
