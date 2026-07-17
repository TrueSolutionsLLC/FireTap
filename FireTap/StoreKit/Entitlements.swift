import Foundation

/// Pure, testable entitlement logic. Kept separate from StoreKit so the
/// unlock rules can be unit-tested without the store.
enum Entitlements {
    /// Pro is unlocked when the lifetime non-consumable is among the verified,
    /// currently-owned product ids.
    static func isProUnlocked(
        ownedProductIDs: Set<String>,
        proProductID: String = AppConfig.storeKitProProductID
    ) -> Bool {
        ownedProductIDs.contains(proProductID)
    }
}

/// Combines Pro entitlement with Safe Mode to decide what the UI may offer.
/// The app is never fully hidden behind the paywall: reading one project is
/// always allowed; Pro gates multiple projects and all write/admin actions.
struct FeatureGate: Sendable {
    let isPro: Bool

    /// Free tier may use a single connected project (read-only). Opening a
    /// different project than the free one requires Pro.
    func canOpenProject(id: String, freeProjectID: String?) -> Bool {
        if isPro { return true }
        guard let freeProjectID else { return true } // first project becomes the free one
        return id == freeProjectID
    }

    /// Whether write/admin actions may be *offered*. Actually performing a
    /// write additionally requires Safe Mode to be unlocked.
    var canOfferWrites: Bool { isPro }
}
