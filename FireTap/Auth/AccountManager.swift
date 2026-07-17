import Foundation
import Observation

/// Coordinates the full connected-account lifecycle: sign-in (PKCE), multi
/// account switching, disconnect (with revocation) and local-credential
/// deletion. This is the app's session authority and the UI's source of truth.
@MainActor
@Observable
final class AccountManager {

    enum Phase: Equatable {
        case idle
        case authenticating
        case exchanging
        case failed(AuthError)
    }

    // Observable state
    private(set) var accounts: [ConnectedAccount] = []
    private(set) var activeAccountID: String?
    private(set) var phase: Phase = .idle

    /// True when a real OAuth client id is configured.
    let isConfigured: Bool = AppConfig.isOAuthConfigured

    var activeAccount: ConnectedAccount? {
        guard let activeAccountID else { return nil }
        return accounts.first { $0.id == activeAccountID }
    }

    var isSignedIn: Bool { activeAccount != nil }

    // Dependencies
    private let oauthClient: OAuthClient
    private let credentialStore: CredentialStoring
    private let tokenService: TokenService
    private let webAuthenticator: WebAuthenticator
    private let requiredScopes: [String]
    private let lastActiveKey = "pc.lastActiveAccountID"
    private let log = RedactedLog(category: "account")

    init(
        oauthClient: OAuthClient,
        credentialStore: CredentialStoring,
        tokenService: TokenService,
        webAuthenticator: WebAuthenticator = WebAuthenticator(),
        requiredScopes: [String] = AppConfig.requiredScopeValues
    ) {
        self.oauthClient = oauthClient
        self.credentialStore = credentialStore
        self.tokenService = tokenService
        self.webAuthenticator = webAuthenticator
        self.requiredScopes = requiredScopes
    }

    // MARK: Bootstrap

    /// Loads persisted accounts from the Keychain and restores the last-used
    /// active account. Does not perform any network calls.
    func bootstrap() async {
        let stored = (try? credentialStore.allCredentials()) ?? []
        accounts = stored.map(\.account).sorted { $0.email < $1.email }

        let remembered = UserDefaults.standard.string(forKey: lastActiveKey)
        let restored = accounts.first { $0.id == remembered } ?? accounts.first
        await setActiveAccount(restored?.id)
    }

    // MARK: Sign-in

    /// Runs the Authorization Code Flow with PKCE end-to-end and, on success,
    /// stores the credential in the Keychain and makes the account active.
    func signIn(loginHint: String? = nil) async {
        guard isConfigured else {
            phase = .failed(.notConfigured)
            return
        }
        phase = .authenticating
        do {
            let pkce = PKCEChallenge.generate()
            let state = OAuthState.generate()
            let authURL = try oauthClient.authorizationURL(
                challenge: pkce,
                state: state,
                loginHint: loginHint
            )

            let callback = try await webAuthenticator.authenticate(
                url: authURL,
                callbackScheme: AppConfig.oauthRedirectScheme
            )
            let code = try OAuthCallback.authorizationCode(from: callback, expectedState: state)

            phase = .exchanging
            let tokenResponse = try await oauthClient.exchange(code: code, verifier: pkce.verifier)

            let grantedScopes = tokenResponse.scope?
                .split(separator: " ").map(String.init) ?? []
            let missing = requiredScopes.filter { !grantedScopes.contains($0) }
            guard missing.isEmpty else {
                throw AuthError.missingScopes(missing: missing.map(Self.shortScope))
            }

            let userInfo = try await oauthClient.fetchUserInfo(accessToken: tokenResponse.accessToken)
            guard let email = userInfo.email else { throw AuthError.missingIdentity }

            let account = ConnectedAccount(
                id: userInfo.sub,
                email: email,
                displayName: userInfo.name,
                avatarURL: userInfo.picture.flatMap(URL.init(string:))
            )
            guard let refreshToken = tokenResponse.refreshToken else {
                // Without a refresh token we couldn't maintain the session.
                throw AuthError.tokenRequest(error: "no_refresh_token",
                                             description: "Google didn't return a refresh token.")
            }
            let credential = StoredCredential(
                account: account,
                refreshToken: refreshToken,
                grantedScopes: grantedScopes
            )
            try credentialStore.save(credential)

            let token = OAuthToken(
                accessToken: tokenResponse.accessToken,
                refreshToken: refreshToken,
                expiresAt: Date.now.addingTimeInterval(TimeInterval(tokenResponse.expiresIn)),
                scopes: grantedScopes,
                tokenType: tokenResponse.tokenType
            )
            await tokenService.cacheToken(token, for: account.id)

            if let index = accounts.firstIndex(where: { $0.id == account.id }) {
                accounts[index] = account
            } else {
                accounts.append(account)
                accounts.sort { $0.email < $1.email }
            }
            await setActiveAccount(account.id)
            phase = .idle
            log.info("Sign-in succeeded for a connected account.")
        } catch let error as AuthError {
            phase = .failed(error)
            log.warning("Sign-in failed: \(String(describing: error))")
        } catch let error as APIError {
            phase = .failed(.tokenRequest(error: "api", description: error.userMessage))
            log.warning("Sign-in failed (api): \(String(describing: error))")
        } catch {
            phase = .failed(.tokenRequest(error: "unknown", description: nil))
        }
    }

    func clearError() {
        if case .failed = phase { phase = .idle }
    }

    // MARK: Account switching

    func setActiveAccount(_ id: String?) async {
        activeAccountID = id
        await tokenService.setActiveAccount(id)
        if let id {
            UserDefaults.standard.set(id, forKey: lastActiveKey)
        } else {
            UserDefaults.standard.removeObject(forKey: lastActiveKey)
        }
    }

    // MARK: Disconnect / delete

    /// Disconnects an account: best-effort token revocation with Google, then
    /// deletes the local credential.
    func disconnect(accountID: String) async {
        if let credential = try? credentialStore.credential(forAccountID: accountID) {
            try? await oauthClient.revoke(token: credential.refreshToken)
        }
        try? credentialStore.delete(accountID: accountID)
        await tokenService.forget(accountID)
        accounts.removeAll { $0.id == accountID }
        if activeAccountID == accountID {
            await setActiveAccount(accounts.first?.id)
        }
    }

    /// Deletes ALL locally stored credentials without contacting Google.
    /// (The grant may still exist in the user's Google account until revoked.)
    func deleteLocalCredentials() async {
        try? credentialStore.deleteAll()
        await tokenService.forgetAll()
        accounts.removeAll()
        await setActiveAccount(nil)
    }

    private static func shortScope(_ scope: String) -> String {
        scope.split(separator: "/").last.map(String.init) ?? scope
    }
}
