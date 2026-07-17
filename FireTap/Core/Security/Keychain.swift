import Foundation
import Security

/// Low-level, thread-safe wrapper around the iOS Keychain for generic
/// password items. Used to persist OAuth refresh tokens and account records.
///
/// Items are stored with `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`
/// so they are never synced to iCloud and never leave the device.
struct Keychain: Sendable {

    enum KeychainError: Error, Equatable {
        case unexpectedStatus(OSStatus)
        case dataConversionFailed
    }

    let service: String

    init(service: String) {
        self.service = service
    }

    // MARK: CRUD

    func set(_ data: Data, for account: String) throws {
        var query = baseQuery(account: account)
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        let status = SecItemCopyMatching(query as CFDictionary, nil)
        switch status {
        case errSecSuccess:
            let update = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
            guard update == errSecSuccess else { throw KeychainError.unexpectedStatus(update) }
        case errSecItemNotFound:
            query.merge(attributes) { _, new in new }
            let add = SecItemAdd(query as CFDictionary, nil)
            guard add == errSecSuccess else { throw KeychainError.unexpectedStatus(add) }
        default:
            throw KeychainError.unexpectedStatus(status)
        }
    }

    func data(for account: String) throws -> Data? {
        var query = baseQuery(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        switch status {
        case errSecSuccess:
            return item as? Data
        case errSecItemNotFound:
            return nil
        default:
            throw KeychainError.unexpectedStatus(status)
        }
    }

    func remove(account: String) throws {
        let status = SecItemDelete(baseQuery(account: account) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    /// Returns every account name stored for this service.
    func allAccounts() throws -> [String] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll
        ]
        query[kSecReturnData as String] = false

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        switch status {
        case errSecSuccess:
            let items = (result as? [[String: Any]]) ?? []
            return items.compactMap { $0[kSecAttrAccount as String] as? String }
        case errSecItemNotFound:
            return []
        default:
            throw KeychainError.unexpectedStatus(status)
        }
    }

    func removeAll() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    // MARK: Helpers

    private func baseQuery(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}
