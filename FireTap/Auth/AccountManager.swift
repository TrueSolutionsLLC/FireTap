import Foundation
import Observation

/// Coordinates the Google Sign-In session: interactive sign-in, silent restore,
/// account switching, disconnect, and local credential deletion. Tokens remain
/// in the Google Sign-In SDK's Keychain-backed store — never UserDefaults.
@MainActor
@Observable
final class AccountManager {

    enum Phase: Equatable {
        case idle
        case restoring
        case authenticating
        case failed(AuthError)
    }

    private(set) var accounts: [ConnectedAccount] = []
    private(set) var activeAccountID: String?
    private(set) var phase: Phase = .idle
    private(set) var grantedScopes: [String] = []

    let isConfigured: Bool

    var activeAccount: ConnectedAccount? {
        guard let activeAccountID else { return nil }
        return accounts.first { $0.id == activeAccountID }
    }

    var isSignedIn: Bool { activeAccount != nil }

    /// True when the session already includes scopes sufficient for write/admin APIs.
    /// `cloud-platform` covers Cloud/Firebase admin; otherwise each configured write scope is required.
    var hasWriteScopes: Bool {
        if grantedScopes.contains(where: { $0.contains("cloud-platform") }) {
            return true
        }
        return AppConfig.writeScopeValues.allSatisfy { needed in
            grantedScopes.contains { $0 == needed || $0.hasSuffix(needed) }
        }
    }

    private let session: GoogleSignInSessioning
    private let requiredScopes: [String]
    private let initialScopes: [String]
    private let knownAccountsKey = "pc.knownAccountIDs"
    private let log = RedactedLog(category: "account")

    init(
        session: GoogleSignInSessioning,
        isConfigured: Bool = AppConfig.isOAuthConfigured,
        requiredScopes: [String] = AppConfig.requiredScopeValues,
        initialScopes: [String] = AppConfig.oauthScopes.map(\.value)
    ) {
        self.session = session
        self.isConfigured = isConfigured
        self.requiredScopes = requiredScopes
        self.initialScopes = initialScopes
    }

    // MARK: Bootstrap

    /// Restores a previous Google Sign-In session from the SDK Keychain.
    func bootstrap() async {
        guard isConfigured else {
            phase = .idle
            return
        }
        phase = .restoring
        session.configure()
        do {
            if let user = try await session.restorePreviousSignIn() {
                apply(user)
                phase = .idle
                log.info("Restored previous Google Sign-In session.")
            } else {
                accounts = []
                activeAccountID = nil
                grantedScopes = []
                phase = .idle
            }
        } catch {
            accounts = []
            activeAccountID = nil
            grantedScopes = []
            phase = .idle
            log.warning("Session restore failed; presenting signed-out state.")
        }
    }

    // MARK: Sign-in / switch

    /// Interactive Google Sign-In. Pass `loginHint` when switching to a known
    /// account. Uses only the Phase 1 initial scopes (identity + read-only
    /// Firebase). Additional scopes are requested later via incremental auth.
    func signIn(loginHint: String? = nil) async {
        guard isConfigured else {
            phase = .failed(.notConfigured)
            return
        }
        guard let presenter = PresentationAnchor.rootViewController() else {
            phase = .failed(.invalidRequest)
            return
        }
        phase = .authenticating
        do {
            let user = try await session.signIn(
                presenting: presenter,
                loginHint: loginHint,
                additionalScopes: Self.signInAdditionalScopes(from: initialScopes)
            )
            try validateScopes(user.grantedScopes)
            apply(user)
            phase = .idle
            log.info("Sign-in succeeded.")
        } catch let error as AuthError {
            phase = .failed(error)
            log.warning("Sign-in failed.")
        } catch {
            phase = .failed(.tokenRequest(error: "unknown", description: nil))
        }
    }

    /// Signs in with a different Google account (replaces the active SDK session).
    func switchAccount() async {
        await signIn(loginHint: nil)
    }

    func clearError() {
        if case .failed = phase { phase = .idle }
    }

    // MARK: Sign-out / disconnect

    /// Removes the local SDK session (Keychain). The Google grant remains until
    /// the user revokes it in their Google account or we call `disconnect`.
    func signOut() async {
        session.signOut()
        accounts = []
        activeAccountID = nil
        grantedScopes = []
        clearKnownAccountIDs()
        phase = .idle
        log.info("Signed out; local credentials cleared.")
    }

    /// Revokes FireTap's Google grant and clears local SDK credentials.
    func disconnect(accountID: String) async {
        guard activeAccountID == accountID || accounts.contains(where: { $0.id == accountID }) else {
            return
        }
        do {
            try await session.disconnect()
        } catch {
            session.signOut()
        }
        accounts = []
        activeAccountID = nil
        grantedScopes = []
        clearKnownAccountIDs()
        phase = .idle
    }

    /// Deletes all local credentials without attempting Google revocation.
    func deleteLocalCredentials() async {
        session.signOut()
        accounts = []
        activeAccountID = nil
        grantedScopes = []
        clearKnownAccountIDs()
        phase = .idle
    }

    /// Incremental authorization for write scopes (Phase 2+). Not used in Phase 1.
    func requestWriteScopes() async throws {
        guard let presenter = PresentationAnchor.rootViewController() else {
            throw AuthError.invalidRequest
        }
        let user = try await session.requestAdditionalScopes(
            AppConfig.writeScopeValues,
            presenting: presenter
        )
        try validateScopes(requiredScopes)
        apply(user)
    }

    // MARK: Private

    private func apply(_ user: GoogleSignedInUser) {
        guard !user.email.isEmpty else {
            phase = .failed(.missingIdentity)
            return
        }
        let account = ConnectedAccount(
            id: user.id,
            email: user.email,
            displayName: user.displayName,
            avatarURL: user.avatarURL
        )
        accounts = [account]
        activeAccountID = account.id
        grantedScopes = user.grantedScopes
        remember(accountID: account.id)
    }

    private func validateScopes(_ granted: [String]) throws {
        let missing = requiredScopes.filter { needed in
            !granted.contains(where: { $0 == needed || $0.hasSuffix(needed) })
        }
        // Google sometimes returns short scope names; also accept if cloud-platform
        // was granted (superset) even though we no longer request it up front.
        let stillMissing = missing.filter { needed in
            if needed.contains("firebase.readonly") {
                return !granted.contains(where: {
                    $0.contains("firebase.readonly")
                        || $0.contains("firebase")
                        || $0.contains("cloud-platform")
                })
            }
            return true
        }
        guard stillMissing.isEmpty else {
            throw AuthError.missingScopes(missing: stillMissing.map(Self.shortScope))
        }
    }

    /// OpenID scopes are requested via GIDConfiguration / default; additional
    /// scopes passed to `signIn` should be the Google API scopes only.
    private static func signInAdditionalScopes(from all: [String]) -> [String] {
        all.filter { $0.hasPrefix("https://") }
    }

    private static func shortScope(_ scope: String) -> String {
        scope.split(separator: "/").last.map(String.init) ?? scope
    }

    private func remember(accountID: String) {
        // Non-sensitive id only — never tokens. Used for UI continuity checks.
        UserDefaults.standard.set([accountID], forKey: knownAccountsKey)
    }

    private func clearKnownAccountIDs() {
        UserDefaults.standard.removeObject(forKey: knownAccountsKey)
    }
}
