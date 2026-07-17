import Foundation

/// A live OAuth access token plus the material needed to refresh it.
struct OAuthToken: Sendable, Equatable {
    var accessToken: String
    var refreshToken: String?
    var expiresAt: Date
    var scopes: [String]
    var tokenType: String

    /// Treat tokens as expired slightly early to avoid mid-flight expiry.
    func isExpired(now: Date = .now, leeway: TimeInterval = 60) -> Bool {
        now.addingTimeInterval(leeway) >= expiresAt
    }
}

/// Persistent per-account credential. The refresh token is the only long-lived
/// secret and lives exclusively in the Keychain (never UserDefaults).
struct StoredCredential: Codable, Sendable, Equatable {
    var account: ConnectedAccount
    var refreshToken: String
    var grantedScopes: [String]

    /// True when the stored grant covers every scope the app currently needs.
    func satisfies(requiredScopes: [String]) -> Bool {
        let granted = Set(grantedScopes)
        return requiredScopes.allSatisfy { granted.contains($0) }
    }
}

/// Raw token endpoint response (`https://oauth2.googleapis.com/token`).
struct TokenResponse: Decodable, Sendable {
    let accessToken: String
    let expiresIn: Int
    let refreshToken: String?
    let scope: String?
    let tokenType: String
    let idToken: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case expiresIn = "expires_in"
        case refreshToken = "refresh_token"
        case scope
        case tokenType = "token_type"
        case idToken = "id_token"
    }
}
