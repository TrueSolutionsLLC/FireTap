import XCTest
@testable import FireTap

final class NetworkingTests: XCTestCase {
    func testBackoffRespectsRetryAfter() {
        let backoff = Backoff(base: 0.5, cap: 20, maxRetries: 4)
        XCTAssertEqual(backoff.delay(forAttempt: 3, retryAfter: 7.5), 7.5)
    }

    func testBackoffStaysWithinBounds() {
        let backoff = Backoff(base: 0.5, cap: 4, maxRetries: 6)
        for attempt in 0..<10 {
            let delay = backoff.delay(forAttempt: attempt)
            XCTAssertGreaterThanOrEqual(delay, 0)
            XCTAssertLessThanOrEqual(delay, 4)
        }
    }

    func testGoogleErrorDecoding() throws {
        let json = """
        { "error": { "code": 403, "message": "Permission denied", "status": "PERMISSION_DENIED",
          "errors": [ { "message": "denied", "domain": "global", "reason": "forbidden" } ] } }
        """.data(using: .utf8)!
        let error = try JSONDecoder().decode(GoogleAPIError.self, from: json)
        XCTAssertEqual(error.code, 403)
        XCTAssertEqual(error.status, "PERMISSION_DENIED")
        XCTAssertEqual(error.message, "Permission denied")
        XCTAssertEqual(error.errors?.first?.reason, "forbidden")
    }

    func testHTTPRequestResolvesQuery() {
        let request = HTTPRequest(.get, url: URL(string: "https://example.com/v1/x")!,
                                  query: [URLQueryItem(name: "pageSize", value: "50")])
        XCTAssertEqual(request.resolvedURL.absoluteString, "https://example.com/v1/x?pageSize=50")
    }

    func testRedactedURLStripsQueryValues() {
        let url = URL(string: "https://example.com/v1/docs?access_token=SECRET&pageSize=10")!
        let redacted = RedactedLog.redactURL(url)
        XCTAssertFalse(redacted.contains("SECRET"))
        XCTAssertTrue(redacted.contains("example.com/v1/docs"))
    }

    func testTokenResponseDecoding() throws {
        let json = """
        { "access_token": "AT", "expires_in": 3599, "refresh_token": "RT",
          "scope": "openid email", "token_type": "Bearer", "id_token": "IDT" }
        """.data(using: .utf8)!
        let token = try JSONDecoder().decode(TokenResponse.self, from: json)
        XCTAssertEqual(token.accessToken, "AT")
        XCTAssertEqual(token.expiresIn, 3599)
        XCTAssertEqual(token.refreshToken, "RT")
    }
}
