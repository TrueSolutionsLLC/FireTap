import Foundation
import Observation

@MainActor
@Observable
final class RealtimeDatabasePathViewModel {
    let projectID: String
    let databaseURL: URL
    let path: String

    private(set) var snapshot: RealtimeDatabaseSnapshot?
    var draftJSON = ""
    private(set) var isLoading = false
    private(set) var isSaving = false
    private(set) var isDeleting = false
    private(set) var error: APIError?
    private(set) var conflictDetected = false
    private(set) var largeReadWarning: String?

    var isEditing = false
    var newChildKey = ""
    var newChildJSON = "null"

    private let service: RealtimeDatabaseService
    private let audit: AuditLogging

    /// Warn when a single read exceeds this many bytes.
    static let largeReadThresholdBytes = 100 * 1_024

    init(
        projectID: String,
        databaseURL: URL,
        path: String,
        service: RealtimeDatabaseService,
        audit: AuditLogging
    ) {
        self.projectID = projectID
        self.databaseURL = databaseURL
        self.path = path
        self.service = service
        self.audit = audit
    }

    var displayPath: String {
        path.isEmpty ? "/" : "/\(path)"
    }

    var canEdit: Bool {
        snapshot != nil && !isLoading
    }

    var hasDraftChanges: Bool {
        guard let snapshot else { return false }
        return draftJSON.trimmingCharacters(in: .whitespacesAndNewlines)
            != snapshot.text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var childKeys: [String] {
        guard let snapshot,
              let object = try? JSONSerialization.jsonObject(with: snapshot.data),
              let dictionary = object as? [String: Any]
        else { return [] }
        return dictionary.keys.sorted()
    }

    func childPath(for key: String) -> String {
        if path.isEmpty { return key }
        return "\(path)/\(key)"
    }

    func load(forceFullDepth: Bool = false) async {
        if snapshot == nil { isLoading = true }
        error = nil
        conflictDetected = false
        largeReadWarning = nil
        defer { isLoading = false }
        do {
            let loaded = try await service.getSnapshot(
                databaseURL: databaseURL,
                path: path,
                shallow: !forceFullDepth && path.isEmpty,
                timeout: 30
            )
            if loaded.byteCount >= Self.largeReadThresholdBytes {
                largeReadWarning = "This node is about \(ByteCountFormatter.string(fromByteCount: Int64(loaded.byteCount), countStyle: .file)). Large reads can increase billing."
            }
            snapshot = loaded
            draftJSON = prettyJSON(from: loaded.data) ?? loaded.text
            isEditing = false
        } catch let api as APIError {
            error = api
        } catch {
            self.error = .transport(underlying: "unknown")
        }
    }

    func beginEditing() {
        guard let snapshot else { return }
        draftJSON = prettyJSON(from: snapshot.data) ?? snapshot.text
        isEditing = true
    }

    func cancelEditing() {
        if let snapshot {
            draftJSON = prettyJSON(from: snapshot.data) ?? snapshot.text
        }
        isEditing = false
        error = nil
        conflictDetected = false
    }

    func save() async -> Bool {
        guard !isSaving, let snapshot else { return false }
        guard let normalized = normalizedDraftData() else {
            error = .decoding(context: "RTDB JSON")
            return false
        }
        isSaving = true
        error = nil
        conflictDetected = false
        defer { isSaving = false }
        do {
            let _ = try await service.putJSON(
                databaseURL: databaseURL,
                path: path,
                data: normalized,
                ifMatch: snapshot.etag,
                timeout: 30
            )
            await audit.record(AuditEntry(
                accountID: nil,
                projectID: projectID,
                action: "rtdb.put",
                resource: displayPath,
                summary: "Updated RTDB node",
                reversible: false,
                beforeValue: truncated(snapshot.text),
                afterValue: truncated(String(data: normalized, encoding: .utf8) ?? "")
            ))
            isEditing = false
            await load(forceFullDepth: true)
            return true
        } catch APIError.preconditionFailed {
            conflictDetected = true
            error = .preconditionFailed(message: "This node changed since you loaded it.")
            return false
        } catch let api as APIError {
            error = api
            return false
        } catch {
            self.error = .transport(underlying: "unknown")
            return false
        }
    }

    func createChild() async -> Bool {
        let key = newChildKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return false }
        guard let valueData = normalizedChildData() else {
            error = .decoding(context: "RTDB child JSON")
            return false
        }
        isSaving = true
        error = nil
        defer { isSaving = false }
        do {
            _ = try await service.putJSON(
                databaseURL: databaseURL,
                path: childPath(for: key),
                data: valueData,
                ifMatch: nil,
                timeout: 30
            )
            await audit.record(AuditEntry(
                accountID: nil,
                projectID: projectID,
                action: "rtdb.create_child",
                resource: "/\(childPath(for: key))",
                summary: "Created RTDB child node",
                reversible: false
            ))
            newChildKey = ""
            newChildJSON = "null"
            await load(forceFullDepth: true)
            return true
        } catch let api as APIError {
            error = api
            return false
        } catch {
            self.error = .transport(underlying: "unknown")
            return false
        }
    }

    func deleteNode() async -> Bool {
        guard !isDeleting else { return false }
        isDeleting = true
        error = nil
        conflictDetected = false
        defer { isDeleting = false }
        do {
            try await service.deleteJSON(
                databaseURL: databaseURL,
                path: path,
                ifMatch: snapshot?.etag,
                timeout: 30
            )
            await audit.record(AuditEntry(
                accountID: nil,
                projectID: projectID,
                action: "rtdb.delete",
                resource: displayPath,
                summary: "Deleted RTDB node",
                reversible: false
            ))
            return true
        } catch APIError.preconditionFailed {
            conflictDetected = true
            error = .preconditionFailed(message: "This node changed since you loaded it.")
            return false
        } catch let api as APIError {
            error = api
            return false
        } catch {
            self.error = .transport(underlying: "unknown")
            return false
        }
    }

    private func normalizedDraftData() -> Data? {
        guard let data = draftJSON.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data),
              JSONSerialization.isValidJSONObject(object) || object is NSNull
        else { return nil }
        return try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    }

    private func normalizedChildData() -> Data? {
        let trimmed = newChildJSON.trimmingCharacters(in: .whitespacesAndNewlines)
        let payload = trimmed.isEmpty ? "null" : trimmed
        guard let data = payload.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data),
              JSONSerialization.isValidJSONObject(object) || object is NSNull
        else { return nil }
        return try? JSONSerialization.data(withJSONObject: object)
    }

    private func prettyJSON(from data: Data) -> String? {
        guard let object = try? JSONSerialization.jsonObject(with: data),
              let pretty = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]),
              let string = String(data: pretty, encoding: .utf8)
        else { return nil }
        return string
    }

    private func truncated(_ value: String, limit: Int = 240) -> String {
        if value.count <= limit { return value }
        return String(value.prefix(limit)) + "…"
    }
}
