import XCTest
import CryptoKit
@testable import FireTap

final class PKCETests: XCTestCase {
    func testVerifierLengthAndCharset() {
        let pkce = PKCEChallenge.generate()
        // 32 random bytes base64url-encoded == 43 chars, no padding.
        XCTAssertEqual(pkce.verifier.count, 43)
        XCTAssertFalse(pkce.verifier.contains("="))
        XCTAssertFalse(pkce.verifier.contains("+"))
        XCTAssertFalse(pkce.verifier.contains("/"))
        XCTAssertEqual(pkce.method, "S256")
    }

    func testChallengeIsBase64URLSha256OfVerifier() {
        let pkce = PKCEChallenge(verifier: "test_verifier_fixed_value_1234567890")
        let expected = Data(SHA256.hash(data: Data(pkce.verifier.utf8))).base64URLEncodedString()
        XCTAssertEqual(pkce.challenge, expected)
        XCTAssertFalse(pkce.challenge.contains("="))
    }

    func testGeneratedChallengesAreUnique() {
        let a = PKCEChallenge.generate()
        let b = PKCEChallenge.generate()
        XCTAssertNotEqual(a.verifier, b.verifier)
        XCTAssertNotEqual(a.challenge, b.challenge)
    }

    func testStateIsRandomAndUnpadded() {
        let a = OAuthState.generate()
        let b = OAuthState.generate()
        XCTAssertNotEqual(a, b)
        XCTAssertFalse(a.contains("="))
    }
}
