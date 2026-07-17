import XCTest
@testable import FireTap

/// Exercises the real Keychain (the test host app has a keychain on the
/// simulator). Uses a unique service per run and cleans up.
final class KeychainCredentialStoreTests: XCTestCase {
    private var service = ""
    private var store: KeychainCredentialStore!

    override func setUp() {
        super.setUp()
        service = "com.truesolutions.firetap.tests.\(UUID().uuidString)"
        store = KeychainCredentialStore(service: service)
    }

    override func tearDown() {
        try? store.deleteAll()
        super.tearDown()
    }

    func testSaveAndRead() throws {
        let credential = StoredCredential.fixture(id: "acc-1", refresh: "r1")
        try store.save(credential)
        let loaded = try store.credential(forAccountID: "acc-1")
        XCTAssertEqual(loaded, credential)
    }

    func testUpdateOverwrites() throws {
        try store.save(.fixture(id: "acc-1", refresh: "r1"))
        try store.save(.fixture(id: "acc-1", refresh: "r2"))
        XCTAssertEqual(try store.credential(forAccountID: "acc-1")?.refreshToken, "r2")
    }

    func testDelete() throws {
        try store.save(.fixture(id: "acc-1"))
        try store.delete(accountID: "acc-1")
        XCTAssertNil(try store.credential(forAccountID: "acc-1"))
    }

    func testAllCredentials() throws {
        try store.save(.fixture(id: "acc-1"))
        try store.save(.fixture(id: "acc-2"))
        XCTAssertEqual(try store.allCredentials().count, 2)
    }

    func testDeleteAll() throws {
        try store.save(.fixture(id: "acc-1"))
        try store.save(.fixture(id: "acc-2"))
        try store.deleteAll()
        XCTAssertTrue(try store.allCredentials().isEmpty)
    }

    func testMissingReturnsNil() throws {
        XCTAssertNil(try store.credential(forAccountID: "nope"))
    }
}
