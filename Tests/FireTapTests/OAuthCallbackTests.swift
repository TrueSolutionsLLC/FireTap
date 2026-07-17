import XCTest
@testable import FireTap

final class OAuthCallbackTests: XCTestCase {
    private let scheme = "com.example.app"

    func testValidCallbackReturnsCode() throws {
        let state = "abc123"
        let url = URL(string: "\(scheme):/oauth2redirect?code=AUTH_CODE&state=\(state)")!
        let code = try OAuthCallback.authorizationCode(from: url, expectedState: state)
        XCTAssertEqual(code, "AUTH_CODE")
    }

    func testStateMismatchIsRejected() {
        let url = URL(string: "\(scheme):/oauth2redirect?code=AUTH_CODE&state=WRONG")!
        XCTAssertThrowsError(try OAuthCallback.authorizationCode(from: url, expectedState: "RIGHT")) { error in
            XCTAssertEqual(error as? AuthError, .stateMismatch)
        }
    }

    func testMissingStateIsRejected() {
        let url = URL(string: "\(scheme):/oauth2redirect?code=AUTH_CODE")!
        XCTAssertThrowsError(try OAuthCallback.authorizationCode(from: url, expectedState: "RIGHT")) { error in
            XCTAssertEqual(error as? AuthError, .stateMismatch)
        }
    }

    func testMissingCodeIsRejected() {
        let url = URL(string: "\(scheme):/oauth2redirect?state=RIGHT")!
        XCTAssertThrowsError(try OAuthCallback.authorizationCode(from: url, expectedState: "RIGHT")) { error in
            XCTAssertEqual(error as? AuthError, .missingAuthorizationCode)
        }
    }

    func testAuthorizationDeniedIsSurfaced() {
        let url = URL(string: "\(scheme):/oauth2redirect?error=access_denied&state=RIGHT")!
        XCTAssertThrowsError(try OAuthCallback.authorizationCode(from: url, expectedState: "RIGHT")) { error in
            XCTAssertEqual(error as? AuthError, .authorizationDenied("access_denied"))
        }
    }

    func testConstantTimeEquals() {
        XCTAssertTrue(OAuthCallback.constantTimeEquals("abcdef", "abcdef"))
        XCTAssertFalse(OAuthCallback.constantTimeEquals("abcdef", "abcdeg"))
        XCTAssertFalse(OAuthCallback.constantTimeEquals("abc", "abcd"))
    }
}
