import Foundation

public let providerEventDetailsKeyProvider = "Provider"
public let providerEventDetailsKeyClient = "Client"
public let providerEventDetailsKeyError = "Error"

public enum ProviderEvent {
    case ready(ProviderEventData)
    case error(ProviderEventData)
    case configurationChanged
    case stale
    case notReady
}

public struct ProviderEventData {
    public let ctxHash: Int
    public init(ctxHash: Int) {
        self.ctxHash = ctxHash
    }
}
