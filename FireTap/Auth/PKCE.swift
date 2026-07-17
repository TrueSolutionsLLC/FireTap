import Foundation
import CryptoKit

/// Proof Key for Code Exchange (RFC 7636) material for the Authorization Code
/// Flow. A fresh `PKCEChallenge` is created per sign-in attempt.
struct PKCEChallenge: Sendable, Equatable {
    /// High-entropy random string (43 chars, base64url of 32 bytes).
    let verifier: String
    /// base64url(SHA256(verifier)).
    let challenge: String
    /// Always "S256" for this app; plain is never used.
    let method: String

    init(verifier: String) {
        self.verifier = verifier
        let digest = SHA256.hash(data: Data(verifier.utf8))
        self.challenge = Data(digest).base64URLEncodedString()
        self.method = "S256"
    }

    /// Generates a new challenge using a cryptographically secure verifier.
    static func generate() -> PKCEChallenge {
        PKCEChallenge(verifier: Data.randomBytes(count: 32).base64URLEncodedString())
    }
}

/// Opaque anti-CSRF `state` value round-tripped through the authorization
/// request and validated on callback.
enum OAuthState {
    static func generate() -> String {
        Data.randomBytes(count: 32).base64URLEncodedString()
    }
}

extension Data {
    /// Cryptographically secure random bytes.
    static func randomBytes(count: Int) -> Data {
        var bytes = [UInt8](repeating: 0, count: count)
        let status = SecRandomCopyBytes(kSecRandomDefault, count, &bytes)
        if status != errSecSuccess {
            // Fall back to SystemRandomNumberGenerator (still cryptographically
            // secure on Apple platforms) rather than crashing.
            var generator = SystemRandomNumberGenerator()
            bytes = (0..<count).map { _ in UInt8.random(in: .min ... .max, using: &generator) }
        }
        return Data(bytes)
    }

    /// base64url without padding (RFC 4648 §5).
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
