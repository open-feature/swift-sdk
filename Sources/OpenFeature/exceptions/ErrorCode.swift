import Foundation

public enum ErrorCode: Int {
    case providerNotReady
    case flagNotFound
    case parseError
    case typeMismatch
    case targetingKeyMissing
    case invalidContext
    case general
    case providerFatal
}
