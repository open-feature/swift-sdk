import Foundation

/// Records which ``OpenFeatureAPI`` instance owns each provider, guarding spec requirement
/// 1.8.4: a provider should not be claimed by two API instances at the same time.
///
/// Claims are keyed by object identity (`ObjectIdentifier`, never `==`), and both sides are
/// weak: a discarded provider or API instance cannot leak the other. Value-type providers
/// are exempt — every copy carries independent state, mirroring how ``OpenFeatureAPI``
/// already treats value providers as distinct instances.
///
/// Locking: `queue` is a leaf lock. It is never held while acquiring another lock, and no
/// method here calls back into ``OpenFeatureAPI``. ``OpenFeatureAPI`` may call these methods
/// while holding its state queue, which makes `stateQueue -> queue` the only lock order.
enum ProviderOwnership {
    private static let queue = DispatchQueue(label: "com.openfeature.provider-ownership")

    private final class Claim {
        weak var provider: AnyObject?
        weak var holder: OpenFeatureAPI?
    }

    private static var claims: [ObjectIdentifier: Claim] = [:]

    /// Claims `provider` for `owner`. Returns `false` when another API instance already
    /// holds the claim, in which case the existing ownership is left intact (spec 1.8.4);
    /// the caller is expected to reject the registration.
    ///
    /// Claiming again for the current owner is allowed: re-setting a provider on the same
    /// instance is not a replacement.
    static func claim(_ provider: FeatureProvider, for owner: OpenFeatureAPI) -> Bool {
        // Value-type providers cannot be keyed by identity: `as AnyObject` would box every
        // copy into a fresh object. They are exempt from ownership instead.
        guard type(of: provider) is AnyClass else {
            return true
        }
        let object = provider as AnyObject
        return queue.sync {
            sweepExpiredClaims()
            let key = ObjectIdentifier(object)
            if let holder = claims[key]?.holder, holder !== owner {
                return false
            }
            let claim = Claim()
            claim.provider = object
            claim.holder = owner
            claims[key] = claim
            return true
        }
    }

    /// Releases the claim, but only when `owner` still holds it. Idempotent.
    ///
    /// A provider that is no longer associated with an API instance can be claimed by
    /// another one (spec 1.8.4).
    static func release(_ provider: FeatureProvider, heldBy owner: OpenFeatureAPI) {
        guard type(of: provider) is AnyClass else {
            return
        }
        let object = provider as AnyObject
        queue.sync {
            let key = ObjectIdentifier(object)
            if claims[key]?.holder === owner {
                claims[key] = nil
            }
        }
    }

    /// Drops claims whose provider or holder has deallocated, so the registry cannot
    /// accumulate dead entries. Callers must hold `queue`.
    private static func sweepExpiredClaims() {
        claims = claims.filter { $0.value.provider != nil && $0.value.holder != nil }
    }
}
