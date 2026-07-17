import Foundation
@testable import FireTap

// MARK: - In-memory credential store

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

// MARK: - Fake OAuth client

final class FakeOAuthClient: OAuthClient, @unchecked Sendable {
    private let lock = NSLock()
    private(set) var refreshCallCount = 0
    var refreshDelay: TimeInterval = 0
    var nextAccessToken = "access-token"
    var rotateRefreshToken: String?
    var refreshShouldFail: AuthError?

    func authorizationURL(challenge: PKCEChallenge, state: String, loginHint: String?) throws -> URL {
        URL(string: "https://accounts.google.com/o/oauth2/v2/auth?state=\(state)")!
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
                             scope: "openid https://www.googleapis.com/auth/cloud-platform",
                             tokenType: "Bearer", idToken: nil)
    }

    func revoke(token: String) async throws {}

    func fetchUserInfo(accessToken: String) async throws -> UserInfo {
        UserInfo(sub: "sub-123", email: "dev@example.com", name: "Dev", picture: nil)
    }
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

// MARK: - Mutable clock (thread-safe, for time-based tests)

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
            grantedScopes: ["openid", "https://www.googleapis.com/auth/cloud-platform"]
        )
    }
}
