import Foundation

/// Supplies a valid bearer token for the active account, refreshing as needed.
/// API clients depend on this abstraction, never on the concrete session.
protocol TokenProviding: Sendable {
    /// Returns a non-expired access token for the active account, refreshing if
    /// necessary. Pass `forceRefresh` after a 401 to bypass the cached token.
    func validAccessToken(forceRefresh: Bool) async throws -> String
}

/// Actor that owns live access tokens and coordinates refresh so that
/// concurrent callers never trigger duplicate refresh requests. Refresh tokens
/// are read from the Keychain on demand and never cached at rest elsewhere.
actor TokenService: TokenProviding {
    private let oauthClient: OAuthClient
    private let credentialStore: CredentialStoring
    private let clock: @Sendable () -> Date

    private var activeAccountID: String?
    private var liveTokens: [String: OAuthToken] = [:]
    private var refreshTasks: [String: Task<OAuthToken, Error>] = [:]

    init(
        oauthClient: OAuthClient,
        credentialStore: CredentialStoring,
        clock: @escaping @Sendable () -> Date = { .now }
    ) {
        self.oauthClient = oauthClient
        self.credentialStore = credentialStore
        self.clock = clock
    }

    // MARK: Configuration

    func setActiveAccount(_ id: String?) {
        activeAccountID = id
    }

    /// Seeds a freshly obtained token (e.g. right after sign-in) so the first
    /// API call doesn't have to refresh.
    func cacheToken(_ token: OAuthToken, for accountID: String) {
        liveTokens[accountID] = token
    }

    func forget(_ accountID: String) {
        liveTokens[accountID] = nil
        refreshTasks[accountID]?.cancel()
        refreshTasks[accountID] = nil
        if activeAccountID == accountID { activeAccountID = nil }
    }

    func forgetAll() {
        liveTokens.removeAll()
        for task in refreshTasks.values { task.cancel() }
        refreshTasks.removeAll()
        activeAccountID = nil
    }

    // MARK: TokenProviding

    func validAccessToken(forceRefresh: Bool) async throws -> String {
        guard let accountID = activeAccountID else { throw APIError.notAuthenticated }
        if !forceRefresh,
           let token = liveTokens[accountID],
           !token.isExpired(now: clock()) {
            return token.accessToken
        }
        let refreshed = try await refresh(accountID: accountID)
        return refreshed.accessToken
    }

    /// Returns a valid token for a *specific* account (used by the account
    /// switcher to validate a stored account before making it active).
    func validAccessToken(for accountID: String, forceRefresh: Bool = false) async throws -> String {
        if !forceRefresh,
           let token = liveTokens[accountID],
           !token.isExpired(now: clock()) {
            return token.accessToken
        }
        return try await refresh(accountID: accountID).accessToken
    }

    // MARK: Refresh (deduplicated)

    private func refresh(accountID: String) async throws -> OAuthToken {
        if let inFlight = refreshTasks[accountID] {
            return try await inFlight.value
        }
        let task = Task { [oauthClient, credentialStore, clock] () throws -> OAuthToken in
            guard let credential = try credentialStore.credential(forAccountID: accountID) else {
                throw APIError.notAuthenticated
            }
            let response = try await oauthClient.refresh(refreshToken: credential.refreshToken)
            let token = OAuthToken(
                accessToken: response.accessToken,
                refreshToken: response.refreshToken ?? credential.refreshToken,
                expiresAt: clock().addingTimeInterval(TimeInterval(response.expiresIn)),
                scopes: response.scope?.split(separator: " ").map(String.init) ?? credential.grantedScopes,
                tokenType: response.tokenType
            )
            // If Google rotated the refresh token, persist the new one.
            if let newRefresh = response.refreshToken, newRefresh != credential.refreshToken {
                var updated = credential
                updated.refreshToken = newRefresh
                try? credentialStore.save(updated)
            }
            return token
        }
        refreshTasks[accountID] = task
        do {
            let token = try await task.value
            liveTokens[accountID] = token
            refreshTasks[accountID] = nil
            return token
        } catch {
            refreshTasks[accountID] = nil
            throw error
        }
    }
}
