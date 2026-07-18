import Foundation
import GoogleSignIn
import UIKit

/// Live Google Sign-In SDK wrapper. Tokens stay in the SDK's Keychain store;
/// this type never writes access or refresh tokens to UserDefaults or logs.
@MainActor
final class LiveGoogleSignInSession: GoogleSignInSessioning {
    private let log = RedactedLog(category: "gsi")
    private let refreshGate = TokenRefreshGate()

    nonisolated init() {}

    func configure() {
        guard AppConfig.isOAuthConfigured else { return }
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(
            clientID: AppConfig.oauthClientID
        )
    }

    func restorePreviousSignIn() async throws -> GoogleSignedInUser? {
        configure()
        do {
            let user = try await GIDSignIn.sharedInstance.restorePreviousSignIn()
            return map(user)
        } catch let error as NSError where error.code == GIDSignInError.hasNoAuthInKeychain.rawValue {
            return nil
        } catch let error as NSError where error.domain == GIDSignInError.errorDomain
            && error.code == GIDSignInError.canceled.rawValue {
            return nil
        }
    }

    func signIn(
        presenting viewController: UIViewController,
        loginHint: String?,
        additionalScopes: [String]
    ) async throws -> GoogleSignedInUser {
        configure()
        do {
            let result = try await GIDSignIn.sharedInstance.signIn(
                withPresenting: viewController,
                hint: loginHint,
                additionalScopes: additionalScopes.isEmpty ? nil : additionalScopes
            )
            return map(result.user)
        } catch let error as NSError where error.domain == GIDSignInError.errorDomain
            && error.code == GIDSignInError.canceled.rawValue {
            throw AuthError.userCanceled
        } catch {
            throw AuthError.tokenRequest(error: "sign_in", description: nil)
        }
    }

    nonisolated func validAccessToken(forceRefresh: Bool) async throws -> String {
        try await refreshGate.run { [weak self] in
            guard let self else { throw APIError.notAuthenticated }
            return try await self.refreshAccessTokenOnMain(forceRefresh: forceRefresh)
        }
    }

    func currentUser() -> GoogleSignedInUser? {
        GIDSignIn.sharedInstance.currentUser.map(map)
    }

    func signOut() {
        GIDSignIn.sharedInstance.signOut()
        refreshGate.cancel()
        log.info("Signed out of Google Sign-In session.")
    }

    func disconnect() async throws {
        do {
            try await GIDSignIn.sharedInstance.disconnect()
            refreshGate.cancel()
            log.info("Disconnected Google Sign-In session.")
        } catch {
            // Still clear local session so the app cannot keep using a broken grant.
            GIDSignIn.sharedInstance.signOut()
            refreshGate.cancel()
            throw AuthError.tokenRequest(error: "disconnect", description: nil)
        }
    }

    func requestAdditionalScopes(
        _ scopes: [String],
        presenting viewController: UIViewController
    ) async throws -> GoogleSignedInUser {
        guard let user = GIDSignIn.sharedInstance.currentUser else {
            throw AuthError.reauthenticationRequired
        }
        do {
            let result = try await user.addScopes(scopes, presenting: viewController)
            return map(result.user)
        } catch let error as NSError where error.domain == GIDSignInError.errorDomain
            && error.code == GIDSignInError.canceled.rawValue {
            throw AuthError.userCanceled
        } catch {
            throw AuthError.tokenRequest(error: "add_scopes", description: nil)
        }
    }

    // MARK: Private

    private func refreshAccessTokenOnMain(forceRefresh: Bool) async throws -> String {
        guard let user = GIDSignIn.sharedInstance.currentUser else {
            throw APIError.notAuthenticated
        }
        let expiry = user.accessToken.expirationDate
        let needsRefresh: Bool
        if forceRefresh {
            needsRefresh = true
        } else if let expiry {
            needsRefresh = expiry.timeIntervalSinceNow < 60
        } else {
            needsRefresh = true
        }
        if needsRefresh {
            do {
                try await user.refreshTokensIfNeeded()
            } catch {
                throw APIError.unauthorized
            }
        }
        let token = user.accessToken.tokenString
        guard !token.isEmpty else { throw APIError.unauthorized }
        return token
    }

    private func map(_ user: GIDGoogleUser) -> GoogleSignedInUser {
        let profile = user.profile
        let scopes = Array(user.grantedScopes ?? [])
        return GoogleSignedInUser(
            id: user.userID ?? profile?.email ?? UUID().uuidString,
            email: profile?.email ?? "",
            displayName: profile?.name,
            avatarURL: profile?.imageURL(withDimension: 128),
            grantedScopes: scopes,
            accessToken: user.accessToken.tokenString,
            accessTokenExpiration: user.accessToken.expirationDate
        )
    }
}

/// Bridges the MainActor-bound Google Sign-In session into `TokenProviding`
/// for the networking stack. Safe because all SDK token work is serialized
/// through the session's own refresh deduplication.
final class GoogleSignInTokenProvider: TokenProviding, @unchecked Sendable {
    private let session: any GoogleSignInSessioning

    init(session: any GoogleSignInSessioning) {
        self.session = session
    }

    func validAccessToken(forceRefresh: Bool) async throws -> String {
        try await session.validAccessToken(forceRefresh: forceRefresh)
    }
}
