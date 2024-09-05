import Foundation

public enum ProviderEvent: Equatable {
    case ready
    case error(errorCode: ErrorCode? = nil, message: String? = nil)
    case configurationChanged
    case stale
    case reconciling
    case contextChanged
}
