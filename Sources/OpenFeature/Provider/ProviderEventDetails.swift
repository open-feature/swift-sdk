import Foundation

/// A structure defining a provider event payload.
public struct ProviderEventDetails: Equatable {
    public let flagsChanged: [String]?
    public let message: String?
    public let errorCode: ErrorCode?
    public let eventMetadata: EventMetadata

    public init(
        flagsChanged: [String]? = nil,
        message: String? = nil,
        errorCode: ErrorCode? = nil,
        eventMetadata: EventMetadata = [:]
    ) {
        self.flagsChanged = flagsChanged
        self.message = message
        self.errorCode = errorCode
        self.eventMetadata = eventMetadata
    }
}
