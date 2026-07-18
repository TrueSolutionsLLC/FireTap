import Foundation
import UIKit

/// Snapshot of a signed-in Google user after a successful Google Sign-In SDK
/// flow. Tokens themselves stay in the SDK's Keychain-backed storage — this
/// value only carries identity and granted scopes for the app UI / gates.
struct GoogleSignedInUser: Sendable, Equatable {
    let id: String
    let email: String
    let displayName: String?
    let avatarURL: URL?
    let grantedScopes: [String]
    let accessToken: String
    let accessTokenExpiration: Date?
}

/// Protocol boundary over the official Google Sign-In SDK so production uses
/// `GIDSignIn` while tests inject a deterministic fake. Sensitive credentials
/// never leave Keychain-backed SDK storage in the live implementation.
protocol GoogleSignInSessioning: AnyObject {
    /// Applies `GIDConfiguration` from `AppConfig`. Safe to call repeatedly.
    @MainActor
    func configure()

    /// Restores the previous SDK session from Keychain, if any.
    @MainActor
    func restorePreviousSignIn() async throws -> GoogleSignedInUser?

    /// Interactive sign-in (Authorization Code + PKCE inside the SDK).
    @MainActor
    func signIn(
        presenting viewController: UIViewController,
        loginHint: String?,
        additionalScopes: [String]
    ) async throws -> GoogleSignedInUser

    /// Returns a non-expired access token for the current SDK user, refreshing
    /// via the SDK when needed. Deduplicates concurrent refresh callers.
    func validAccessToken(forceRefresh: Bool) async throws -> String

    /// Current SDK user as an app-facing snapshot, or `nil` if signed out.
    @MainActor
    func currentUser() -> GoogleSignedInUser?

    /// Clears the local SDK session (Keychain). Does not revoke the Google grant.
    @MainActor
    func signOut()

    /// Revokes the Google grant and clears local SDK credentials.
    @MainActor
    func disconnect() async throws

    /// Requests additional OAuth scopes incrementally (used later for writes).
    @MainActor
    func requestAdditionalScopes(
        _ scopes: [String],
        presenting viewController: UIViewController
    ) async throws -> GoogleSignedInUser
}
