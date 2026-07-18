import XCTest
@testable import FireTap

@MainActor
final class PreferencesStoreResourceTests: XCTestCase {
    private func makeStore() -> PreferencesStore {
        PreferencesStore(defaults: UserDefaults(suiteName: UUID().uuidString)!)
    }

    func testFavoritesRoundTrip() {
        let store = makeStore()
        let account = "acc-1"
        let key = ResourceKey.firestoreCollection("users")

        XCTAssertFalse(store.isFavorite(key, account: account))
        store.setFavorite(true, resourceKey: key, account: account)
        XCTAssertTrue(store.isFavorite(key, account: account))
        XCTAssertEqual(store.favoriteResourceKeys(account: account), [key])

        store.setFavorite(false, resourceKey: key, account: account)
        XCTAssertTrue(store.favoriteResourceKeys(account: account).isEmpty)
    }

    func testRecentlyViewedMovesToFront() {
        let store = makeStore()
        let account = "acc-1"
        let a = ResourceKey.firestoreCollection("users")
        let b = ResourceKey.firestoreCollection("orders")

        store.recordRecentlyViewed(a, account: account)
        store.recordRecentlyViewed(b, account: account)
        store.recordRecentlyViewed(a, account: account)

        XCTAssertEqual(store.recentlyViewedResourceKeys(account: account), [a, b])
    }

    func testRecentlyViewedCapsAtTwenty() {
        let store = makeStore()
        let account = "acc-1"

        for index in 0..<25 {
            store.recordRecentlyViewed(ResourceKey.firestoreCollection("c\(index)"), account: account)
        }

        XCTAssertEqual(store.recentlyViewedResourceKeys(account: account).count, 20)
        XCTAssertEqual(store.recentlyViewedResourceKeys(account: account).first, ResourceKey.firestoreCollection("c24"))
    }

    func testClearRecentlyViewed() {
        let store = makeStore()
        let account = "acc-1"
        store.recordRecentlyViewed(ResourceKey.firestoreCollection("users"), account: account)
        store.clearRecentlyViewed(account: account)
        XCTAssertTrue(store.recentlyViewedResourceKeys(account: account).isEmpty)
    }
}
