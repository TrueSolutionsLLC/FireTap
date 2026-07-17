import Foundation
import CryptoKit

/// Append-only local audit log of administrative actions.
protocol AuditLogging: Sendable {
    func record(_ entry: AuditEntry) async
    func entries(limit: Int) async -> [AuditEntry]
    func clear() async
}

/// Encrypted, on-device audit trail. Each entry is sealed with AES-GCM using a
/// symmetric key kept in the Keychain, then appended (base64) to a file in
/// Application Support. Nothing here leaves the device.
actor EncryptedAuditTrail: AuditLogging {
    private let keychain: Keychain
    private let keyAccount = "audit-key"
    private let fileURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private var cachedKey: SymmetricKey?
    private let log = RedactedLog(category: "audit")

    init(service: String = "\(AppConfig.bundleID).audit", fileName: String = "audit.log") {
        self.keychain = Keychain(service: service)
        let base = (try? FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask,
            appropriateFor: nil, create: true
        )) ?? URL(fileURLWithPath: NSTemporaryDirectory())
        self.fileURL = base.appendingPathComponent(fileName)
    }

    func record(_ entry: AuditEntry) async {
        do {
            let key = try loadOrCreateKey()
            let plaintext = try encoder.encode(entry)
            let sealed = try AES.GCM.seal(plaintext, using: key)
            guard let combined = sealed.combined else { return }
            let line = combined.base64EncodedString() + "\n"
            try append(line)
        } catch {
            log.error("Failed to record audit entry.")
        }
    }

    func entries(limit: Int = 200) async -> [AuditEntry] {
        guard let data = try? Data(contentsOf: fileURL),
              let text = String(data: data, encoding: .utf8),
              let key = try? loadOrCreateKey() else {
            return []
        }
        let decoded: [AuditEntry] = text
            .split(separator: "\n")
            .compactMap { line in
                guard let blob = Data(base64Encoded: String(line)),
                      let box = try? AES.GCM.SealedBox(combined: blob),
                      let plaintext = try? AES.GCM.open(box, using: key),
                      let entry = try? decoder.decode(AuditEntry.self, from: plaintext) else {
                    return nil
                }
                return entry
            }
        return Array(decoded.sorted { $0.timestamp > $1.timestamp }.prefix(limit))
    }

    func clear() async {
        try? FileManager.default.removeItem(at: fileURL)
    }

    // MARK: Helpers

    private func loadOrCreateKey() throws -> SymmetricKey {
        if let cachedKey { return cachedKey }
        if let data = try keychain.data(for: keyAccount) {
            let key = SymmetricKey(data: data)
            cachedKey = key
            return key
        }
        let key = SymmetricKey(size: .bits256)
        let raw = key.withUnsafeBytes { Data($0) }
        try keychain.set(raw, for: keyAccount)
        cachedKey = key
        return key
    }

    private func append(_ line: String) throws {
        let data = Data(line.utf8)
        if FileManager.default.fileExists(atPath: fileURL.path) {
            let handle = try FileHandle(forWritingTo: fileURL)
            defer { try? handle.close() }
            try handle.seekToEnd()
            try handle.write(contentsOf: data)
        } else {
            try data.write(to: fileURL, options: [.atomic, .completeFileProtection])
        }
    }
}
