import Foundation
import StoreKit
import Observation

/// StoreKit 2 manager for the single lifetime Pro non-consumable. Loads the
/// product, processes purchases and restores, and keeps `isPro` in sync with
/// verified entitlements via `Transaction.updates`.
@MainActor
@Observable
final class StoreManager {
    enum PurchasePhase: Equatable {
        case idle
        case purchasing
        case restoring
        case pending
        case failed(String)
    }

    private(set) var proProduct: Product?
    private(set) var isPro: Bool = false
    private(set) var phase: PurchasePhase = .idle
    private(set) var productLoadFailed = false
    private(set) var lastTransactionStateMessage: String?

    private let productID: String
    private var updatesTask: Task<Void, Never>?
    private let log = RedactedLog(category: "storekit")

    init(productID: String = AppConfig.storeKitProProductID) {
        self.productID = productID
    }

    /// Formatted price for display, or nil until the product loads.
    var displayPrice: String? { proProduct?.displayPrice }

    func start() {
        updatesTask?.cancel()
        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                await self?.handle(verification: update)
            }
        }
        Task { await loadProduct() }
        Task { await refreshEntitlements() }
    }

    func stop() {
        updatesTask?.cancel()
        updatesTask = nil
    }

    func loadProduct() async {
        do {
            let products = try await Product.products(for: [productID])
            proProduct = products.first
            productLoadFailed = proProduct == nil
            if proProduct != nil {
                productLoadFailed = false
            }
        } catch {
            productLoadFailed = true
            log.warning("Failed to load Pro product.")
        }
    }

    func purchase() async {
        guard let proProduct else {
            phase = .failed("The Pro product isn't available right now.")
            return
        }
        phase = .purchasing
        do {
            let result = try await proProduct.purchase()
            switch result {
            case .success(let verification):
                await handle(verification: verification)
                phase = .idle
            case .userCancelled:
                phase = .idle
            case .pending:
                phase = .pending
                lastTransactionStateMessage = "Your purchase is pending approval. Pro will unlock when the transaction completes."
            @unknown default:
                phase = .idle
            }
        } catch {
            phase = .failed("Purchase couldn't be completed.")
        }
    }

    func restore() async {
        phase = .restoring
        do {
            try await AppStore.sync()
            await refreshEntitlements()
            phase = .idle
        } catch {
            phase = .failed("Couldn't restore purchases.")
        }
    }

    func refreshEntitlements() async {
        var owned: Set<String> = []
        var sawRevokedPro = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                if transaction.productID == productID, transaction.revocationDate != nil {
                    sawRevokedPro = true
                } else if transaction.revocationDate == nil {
                    owned.insert(transaction.productID)
                }
            }
        }
        isPro = Entitlements.isProUnlocked(ownedProductIDs: owned, proProductID: productID)
        if sawRevokedPro, !isPro {
            lastTransactionStateMessage = "Your Pro purchase was revoked. Pro features are no longer available."
        } else if isPro, lastTransactionStateMessage?.contains("revoked") == true {
            lastTransactionStateMessage = nil
        }
    }

    private func handle(verification: VerificationResult<Transaction>) async {
        switch verification {
        case .verified(let transaction):
            await transaction.finish()
            await refreshEntitlements()
        case .unverified:
            // Never grant entitlement for an unverified transaction.
            break
        }
    }
}
