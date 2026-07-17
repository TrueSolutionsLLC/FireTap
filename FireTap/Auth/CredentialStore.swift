import Foundation

/// Persistence boundary for connected accounts and their refresh tokens.
/// The live implementation is Keychain-backed; tests use an in-memory fake.
protocol CredentialStoring: Sendable {
    func save(_ credential: StoredCredential) throws
    func credential(forAccountID id: String) throws -> StoredCredential?
    func allCredentials() throws -> [StoredCredential]
    func delete(accountID: String) throws
    func deleteAll() throws
}

/// Keychain-backed credential store. Each account is one generic-password item
/// whose value is the JSON-encoded `StoredCredential`.
struct KeychainCredentialStore: CredentialStoring {
    private let keychain: Keychain
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(service: String = "\(AppConfig.bundleID).oauth") {
        self.keychain = Keychain(service: service)
    }

    func save(_ credential: StoredCredential) throws {
        let data = try encoder.encode(credential)
        try keychain.set(data, for: credential.account.id)
    }

    func credential(forAccountID id: String) throws -> StoredCredential? {
        guard let data = try keychain.data(for: id) else { return nil }
        return try decoder.decode(StoredCredential.self, from: data)
    }

    func allCredentials() throws -> [StoredCredential] {
        try keychain.allAccounts().compactMap { id in
            guard let data = try keychain.data(for: id) else { return nil }
            return try? decoder.decode(StoredCredential.self, from: data)
        }
    }

    func delete(accountID: String) throws {
        try keychain.remove(account: accountID)
    }

    func deleteAll() throws {
        try keychain.removeAll()
    }
}
