import Foundation

public enum ProviderStatus: String, CaseIterable {
    case notReady = "PROVIDER_NOT_READY"
    case ready = "PROVIDER_READY"
    case error = "PROVIDER_ERROR"
    case stale = "PROVIDER_STALE"
    case fatal = "PROVIDER_FATAL"
    case reconciling = "PROVIDER_RECONCILING"
}
