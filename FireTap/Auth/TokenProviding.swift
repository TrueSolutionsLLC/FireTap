import Foundation

/// Supplies a valid bearer token. Production uses `GoogleSignInTokenProvider`
/// (SDK Keychain). Tests may inject a fake `TokenProviding`.
protocol TokenProviding: Sendable {
    /// Returns a non-expired access token, refreshing if necessary. Pass
    /// `forceRefresh` after a 401 to bypass any cached token.
    func validAccessToken(forceRefresh: Bool) async throws -> String
}
