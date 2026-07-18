import XCTest
@testable import FireTap

final class GoogleSignInTokenProviderTests: XCTestCase {
    func testAccessTokenFromSeededSession() async throws {
        let session = FakeGoogleSignInSession()
        session.seed(.fixture())
        let provider = GoogleSignInTokenProvider(session: session)
        let token = try await provider.validAccessToken(forceRefresh: false)
        XCTAssertEqual(token, "access-token")
        XCTAssertEqual(session.refreshCallCount, 1)
    }

    func testConcurrentCallsDeduplicateRefresh() async throws {
        let session = FakeGoogleSignInSession()
        session.seed(.fixture())
        session.refreshDelay = 0.15
        let provider = GoogleSignInTokenProvider(session: session)

        let tokens = try await withThrowingTaskGroup(of: String.self) { group -> [String] in
            for _ in 0..<12 {
                group.addTask { try await provider.validAccessToken(forceRefresh: false) }
            }
            var results: [String] = []
            for try await value in group { results.append(value) }
            return results
        }

        XCTAssertEqual(tokens.count, 12)
        XCTAssertTrue(tokens.allSatisfy { $0 == "access-token" })
        XCTAssertEqual(session.refreshCallCount, 1)
    }

    func testMissingSessionThrowsNotAuthenticated() async {
        let provider = GoogleSignInTokenProvider(session: FakeGoogleSignInSession())
        do {
            _ = try await provider.validAccessToken(forceRefresh: false)
            XCTFail("expected error")
        } catch {
            XCTAssertEqual(error as? APIError, .notAuthenticated)
        }
    }

    func testForceRefreshFailureMapsUnauthorized() async {
        let session = FakeGoogleSignInSession()
        session.seed(.fixture())
        session.refreshShouldFail = true
        let provider = GoogleSignInTokenProvider(session: session)
        do {
            _ = try await provider.validAccessToken(forceRefresh: true)
            XCTFail("expected error")
        } catch {
            XCTAssertEqual(error as? APIError, .unauthorized)
        }
    }
}
