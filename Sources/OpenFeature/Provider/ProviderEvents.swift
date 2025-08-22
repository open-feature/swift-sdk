import Foundation

public enum ProviderEvent: Equatable {
    case ready(ProviderEventDetails? = nil)
    case error(ProviderEventDetails? = nil)
    case configurationChanged(ProviderEventDetails? = nil)
    case stale(ProviderEventDetails? = nil)
    case reconciling(ProviderEventDetails? = nil)
    case contextChanged(ProviderEventDetails? = nil)
}
