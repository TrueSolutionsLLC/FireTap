import XCTest
@testable import FireTap

final class TokenServiceTests: XCTestCase {
    func testRefreshWhenNoCachedToken() async throws {
        let store = InMemoryCredentialStore()
        try store.save(.fixture())
        let oauth = FakeOAuthClient()
        oauth.nextAccessToken = "fresh-token"
        let service = TokenService(oauthClient: oauth, credentialStore: store)
        await service.setActiveAccount("sub-123")

        let token = try await service.validAccessToken(forceRefresh: false)
        XCTAssertEqual(token, "fresh-token")
        XCTAssertEqual(oauth.refreshCallCount, 1)
    }

    func testConcurrentCallsDeduplicateRefresh() async throws {
        let store = InMemoryCredentialStore()
        try store.save(.fixture())
        let oauth = FakeOAuthClient()
        oauth.refreshDelay = 0.2 // widen the window so calls overlap
        let service = TokenService(oauthClient: oauth, credentialStore: store)
        await service.setActiveAccount("sub-123")

        let tokens = try await withThrowingTaskGroup(of: String.self) { group -> [String] in
            for _ in 0..<12 {
                group.addTask { try await service.validAccessToken(forceRefresh: false) }
            }
            var results: [String] = []
            for try await value in group { results.append(value) }
            return results
        }

        XCTAssertEqual(tokens.count, 12)
        XCTAssertTrue(tokens.allSatisfy { $0 == "access-token" })
        // All concurrent callers must share a single refresh network call.
        XCTAssertEqual(oauth.refreshCallCount, 1)
    }

    func testCachedTokenAvoidsRefresh() async throws {
        let store = InMemoryCredentialStore()
        try store.save(.fixture())
        let oauth = FakeOAuthClient()
        let service = TokenService(oauthClient: oauth, credentialStore: store)
        await service.setActiveAccount("sub-123")
        await service.cacheToken(
            OAuthToken(accessToken: "cached", refreshToken: "refresh",
                       expiresAt: .now.addingTimeInterval(3600), scopes: [], tokenType: "Bearer"),
            for: "sub-123"
        )
        let token = try await service.validAccessToken(forceRefresh: false)
        XCTAssertEqual(token, "cached")
        XCTAssertEqual(oauth.refreshCallCount, 0)
    }

    func testForceRefreshBypassesCache() async throws {
        let store = InMemoryCredentialStore()
        try store.save(.fixture())
        let oauth = FakeOAuthClient()
        oauth.nextAccessToken = "rotated"
        let service = TokenService(oauthClient: oauth, credentialStore: store)
        await service.setActiveAccount("sub-123")
        await service.cacheToken(
            OAuthToken(accessToken: "cached", refreshToken: "refresh",
                       expiresAt: .now.addingTimeInterval(3600), scopes: [], tokenType: "Bearer"),
            for: "sub-123"
        )
        let token = try await service.validAccessToken(forceRefresh: true)
        XCTAssertEqual(token, "rotated")
        XCTAssertEqual(oauth.refreshCallCount, 1)
    }

    func testMissingActiveAccountThrows() async {
        let service = TokenService(oauthClient: FakeOAuthClient(), credentialStore: InMemoryCredentialStore())
        do {
            _ = try await service.validAccessToken(forceRefresh: false)
            XCTFail("expected error")
        } catch {
            XCTAssertEqual(error as? APIError, .notAuthenticated)
        }
    }

    func testRotatedRefreshTokenIsPersisted() async throws {
        let store = InMemoryCredentialStore()
        try store.save(.fixture(refresh: "old-refresh"))
        let oauth = FakeOAuthClient()
        oauth.rotateRefreshToken = "new-refresh"
        let service = TokenService(oauthClient: oauth, credentialStore: store)
        await service.setActiveAccount("sub-123")
        _ = try await service.validAccessToken(forceRefresh: true)
        XCTAssertEqual(try store.credential(forAccountID: "sub-123")?.refreshToken, "new-refresh")
    }
}
