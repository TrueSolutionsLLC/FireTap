import XCTest
@testable import FireTap

final class EntitlementsTests: XCTestCase {
    private let proID = "com.truesolutions.firetap.lifetime"

    func testProUnlockedWhenOwned() {
        XCTAssertTrue(Entitlements.isProUnlocked(ownedProductIDs: [proID], proProductID: proID))
    }

    func testProLockedWhenNotOwned() {
        XCTAssertFalse(Entitlements.isProUnlocked(ownedProductIDs: ["other"], proProductID: proID))
        XCTAssertFalse(Entitlements.isProUnlocked(ownedProductIDs: [], proProductID: proID))
    }

    func testFreeTierCanOpenFirstProject() {
        let gate = FeatureGate(isPro: false)
        XCTAssertTrue(gate.canOpenProject(id: "p1", freeProjectID: nil))
    }

    func testFreeTierLockedToSingleProject() {
        let gate = FeatureGate(isPro: false)
        XCTAssertTrue(gate.canOpenProject(id: "p1", freeProjectID: "p1"))
        XCTAssertFalse(gate.canOpenProject(id: "p2", freeProjectID: "p1"))
    }

    func testProCanOpenAnyProject() {
        let gate = FeatureGate(isPro: true)
        XCTAssertTrue(gate.canOpenProject(id: "p2", freeProjectID: "p1"))
        XCTAssertTrue(gate.canOfferWrites)
    }

    func testFreeTierCannotOfferWrites() {
        XCTAssertFalse(FeatureGate(isPro: false).canOfferWrites)
    }
}

@MainActor
final class StoreManagerMessagingTests: XCTestCase {
    func testPurchaseWithoutLoadedProductShowsUnavailableMessage() async {
        let store = StoreManager(productID: "com.truesolutions.firetap.lifetime")
        await store.purchase()
        guard case .failed(let message) = store.phase else {
            return XCTFail("expected failed phase, got \(store.phase)")
        }
        XCTAssertEqual(message, "The Pro product isn't available right now.")
    }
}
