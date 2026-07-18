import Foundation
import UIKit
@testable import FireTap

// MARK: - In-memory credential store (legacy OAuth helpers / Keychain tests)

final class InMemoryCredentialStore: CredentialStoring, @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [String: StoredCredential] = [:]

    func save(_ credential: StoredCredential) throws {
        lock.lock(); defer { lock.unlock() }
        storage[credential.account.id] = credential
    }
    func credential(forAccountID id: String) throws -> StoredCredential? {
        lock.lock(); defer { lock.unlock() }
        return storage[id]
    }
    func allCredentials() throws -> [StoredCredential] {
        lock.lock(); defer { lock.unlock() }
        return Array(storage.values)
    }
    func delete(accountID: String) throws {
        lock.lock(); defer { lock.unlock() }
        storage[accountID] = nil
    }
    func deleteAll() throws {
        lock.lock(); defer { lock.unlock() }
        storage.removeAll()
    }
}

// MARK: - Fake OAuth client (legacy token-endpoint helpers)

final class FakeOAuthClient: OAuthClient, @unchecked Sendable {
    private let lock = NSLock()
    private(set) var refreshCallCount = 0
    var refreshDelay: TimeInterval = 0
    var nextAccessToken = "access-token"
    var rotateRefreshToken: String?
    var refreshShouldFail: AuthError?

    func authorizationURL(challenge: PKCEChallenge, state: String, loginHint: String?) throws -> URL {
        URL(static: "https://accounts.google.com/o/oauth2/v2/auth")
    }

    func exchange(code: String, verifier: String) async throws -> TokenResponse {
        TokenResponse(accessToken: nextAccessToken, expiresIn: 3600, refreshToken: "refresh",
                      scope: "openid", tokenType: "Bearer", idToken: nil)
    }

    func refresh(refreshToken: String) async throws -> TokenResponse {
        let snapshot: (failure: AuthError?, token: String, rotate: String?) = lock.withLock {
            refreshCallCount += 1
            return (refreshShouldFail, nextAccessToken, rotateRefreshToken)
        }
        if refreshDelay > 0 {
            try? await Task.sleep(nanoseconds: UInt64(refreshDelay * 1_000_000_000))
        }
        if let failure = snapshot.failure { throw failure }
        return TokenResponse(accessToken: snapshot.token, expiresIn: 3600, refreshToken: snapshot.rotate,
                             scope: "openid https://www.googleapis.com/auth/firebase.readonly",
                             tokenType: "Bearer", idToken: nil)
    }

    func revoke(token: String) async throws {}

    func fetchUserInfo(accessToken: String) async throws -> UserInfo {
        UserInfo(sub: "sub-123", email: "dev@example.com", name: "Dev", picture: nil)
    }
}

// MARK: - Fake Google Sign-In session

final class FakeGoogleSignInSession: GoogleSignInSessioning, @unchecked Sendable {
    private let lock = NSLock()
    private var user: GoogleSignedInUser?
    private let refreshGate = TokenRefreshGate()
    private(set) var refreshCallCount = 0
    private(set) var signOutCount = 0
    private(set) var disconnectCount = 0
    var refreshDelay: TimeInterval = 0
    var restoreResult: GoogleSignedInUser?
    var signInResult: GoogleSignedInUser?
    var refreshShouldFail = false
    var accessTokenOverride: String?

    func configure() {}

    func restorePreviousSignIn() async throws -> GoogleSignedInUser? {
        if let restoreResult {
            user = restoreResult
        }
        return user ?? restoreResult
    }

    func signIn(
        presenting viewController: UIViewController,
        loginHint: String?,
        additionalScopes: [String]
    ) async throws -> GoogleSignedInUser {
        guard let signInResult else { throw AuthError.userCanceled }
        user = signInResult
        return signInResult
    }

    func validAccessToken(forceRefresh: Bool) async throws -> String {
        try await refreshGate.run {
            try await self.performRefresh(forceRefresh: forceRefresh)
        }
    }

    func currentUser() -> GoogleSignedInUser? { user }

    func signOut() {
        signOutCount += 1
        user = nil
        refreshGate.cancel()
    }

    func disconnect() async throws {
        disconnectCount += 1
        user = nil
        refreshGate.cancel()
    }

    func requestAdditionalScopes(
        _ scopes: [String],
        presenting viewController: UIViewController
    ) async throws -> GoogleSignedInUser {
        guard let current = user else { throw AuthError.reauthenticationRequired }
        let updated = GoogleSignedInUser(
            id: current.id,
            email: current.email,
            displayName: current.displayName,
            avatarURL: current.avatarURL,
            grantedScopes: Array(Set(current.grantedScopes + scopes)),
            accessToken: current.accessToken,
            accessTokenExpiration: current.accessTokenExpiration
        )
        user = updated
        return updated
    }

    func seed(_ user: GoogleSignedInUser) {
        self.user = user
    }

    private func performRefresh(forceRefresh: Bool) async throws -> String {
        let snapshot: (fail: Bool, token: String, hasUser: Bool) = lock.withLock {
            refreshCallCount += 1
            return (
                refreshShouldFail,
                accessTokenOverride ?? user?.accessToken ?? "access-token",
                user != nil
            )
        }
        if refreshDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(refreshDelay * 1_000_000_000))
        }
        if snapshot.fail { throw APIError.unauthorized }
        guard snapshot.hasUser else { throw APIError.notAuthenticated }
        return snapshot.token
    }
}

extension GoogleSignedInUser {
    static func fixture(
        id: String = "sub-123",
        email: String = "dev@example.com",
        scopes: [String] = [
            "openid",
            "https://www.googleapis.com/auth/userinfo.email",
            "https://www.googleapis.com/auth/firebase.readonly"
        ]
    ) -> GoogleSignedInUser {
        GoogleSignedInUser(
            id: id,
            email: email,
            displayName: "Dev",
            avatarURL: nil,
            grantedScopes: scopes,
            accessToken: "access-token",
            accessTokenExpiration: Date().addingTimeInterval(3600)
        )
    }
}

final class FakeProjectsService: ProjectsService, @unchecked Sendable {
    var pages: [[FirebaseProject]] = []
    var projectByID: [String: FirebaseProject] = [:]
    var listError: APIError?
    var projectError: APIError?
    private(set) var listCallCount = 0

    func listProjects() async throws -> [FirebaseProject] {
        listCallCount += 1
        if let listError { throw listError }
        return pages.flatMap { $0 }
    }

    func project(id: String) async throws -> FirebaseProject {
        if let projectError { throw projectError }
        if let project = projectByID[id] { return project }
        throw APIError.notFound(message: nil)
    }

    func listApps(projectID: String) async throws -> [FirebaseAppInfo] { [] }
}

// MARK: - Fake biometrics

final class FakeBiometrics: BiometricAuthenticating, @unchecked Sendable {
    var result: Result<Bool, BiometricError>
    init(result: Result<Bool, BiometricError> = .success(true)) { self.result = result }
    func canEvaluate() -> Bool { true }
    func biometryName() -> String { "Face ID" }
    func authenticate(reason: String) async throws -> Bool {
        switch result {
        case .success(let value): return value
        case .failure(let error): throw error
        }
    }
}

// MARK: - Mutable clock

final class MutableClock: @unchecked Sendable {
    private let lock = NSLock()
    private var value: Date
    init(_ start: Date) { value = start }
    var now: Date {
        get { lock.lock(); defer { lock.unlock() }; return value }
        set { lock.lock(); value = newValue; lock.unlock() }
    }
}

// MARK: - Helpers

extension StoredCredential {
    static func fixture(id: String = "sub-123", refresh: String = "refresh") -> StoredCredential {
        StoredCredential(
            account: ConnectedAccount(id: id, email: "dev@example.com", displayName: "Dev", avatarURL: nil),
            refreshToken: refresh,
            grantedScopes: ["openid", "https://www.googleapis.com/auth/firebase.readonly"]
        )
    }
}

extension FirebaseProject {
    static func fixture(
        id: String,
        name: String? = nil,
        number: String? = "123",
        state: String? = "ACTIVE"
    ) -> FirebaseProject {
        FirebaseProject(
            projectId: id,
            projectNumber: number,
            displayName: name,
            state: state,
            resources: nil
        )
    }
}
