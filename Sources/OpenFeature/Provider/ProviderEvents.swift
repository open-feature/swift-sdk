import Foundation

public let providerEventDetailsKeyProvider = "Provider"
public let providerEventDetailsKeyClient = "Client"
public let providerEventDetailsKeyError = "Error"

public enum ProviderEvent: String, CaseIterable {
    case ready = "PROVIDER_READY"
    case error = "PROVIDER_ERROR"
    case configurationChanged = "PROVIDER_CONFIGURATION_CHANGED"
    case stale = "PROVIDER_STALE"

    public var notificationName: NSNotification.Name {
        NSNotification.Name(rawValue)
    }
}
