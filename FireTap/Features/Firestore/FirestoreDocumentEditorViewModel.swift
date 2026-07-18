import Foundation
import Observation

@MainActor
@Observable
final class FirestoreDocumentEditorViewModel {
    let projectID: String
    let databaseID: String
    private(set) var document: FirestoreDocument
    private(set) var isSaving = false
    private(set) var isDeleting = false
    private(set) var error: APIError?
    private(set) var conflictDetected = false
    var draftFields: [String: FirestoreValue]
    var newFieldName = ""
    var newFieldStringValue = ""

    private let service: FirestoreService
    private let audit: AuditLogging
    private var writeInFlight = false

    init(projectID: String, databaseID: String, document: FirestoreDocument, service: FirestoreService, audit: AuditLogging) {
        self.projectID = projectID
        self.databaseID = databaseID
        self.document = document
        self.draftFields = document.fields ?? [:]
        self.service = service
        self.audit = audit
    }

    var hasChanges: Bool {
        draftFields != (document.fields ?? [:])
    }

    var beforeAfterSummary: String {
        let before = Set((document.fields ?? [:]).keys)
        let after = Set(draftFields.keys)
        let added = after.subtracting(before).sorted()
        let removed = before.subtracting(after).sorted()
        let changed = before.intersection(after).filter { draftFields[$0] != document.fields?[$0] }.sorted()
        var lines: [String] = []
        if !added.isEmpty { lines.append("Add: \(added.joined(separator: ", "))") }
        if !removed.isEmpty { lines.append("Remove: \(removed.joined(separator: ", "))") }
        if !changed.isEmpty { lines.append("Change: \(changed.joined(separator: ", "))") }
        return lines.isEmpty ? "No field changes." : lines.joined(separator: "\n")
    }

    func addStringField() {
        let name = newFieldName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        draftFields[name] = .string(newFieldStringValue)
        newFieldName = ""
        newFieldStringValue = ""
    }

    func removeField(_ name: String) {
        draftFields[name] = nil
    }

    func reload() async {
        error = nil
        conflictDetected = false
        do {
            document = try await service.getDocument(
                projectID: projectID,
                databaseID: databaseID,
                documentPath: document.relativePath
            )
            draftFields = document.fields ?? [:]
        } catch let api as APIError {
            error = api
        } catch {
            self.error = .transport(underlying: "unknown")
        }
    }

    /// Saves only changed/removed fields via updateMask + updateTime precondition.
    func save() async -> Bool {
        guard !writeInFlight else { return false }
        writeInFlight = true
        defer { writeInFlight = false }
        isSaving = true
        error = nil
        conflictDetected = false
        let before = document.fields ?? [:]
        let after = draftFields
        let mask = Array(Set(before.keys).union(after.keys)).filter { before[$0] != after[$0] }.sorted()
        guard !mask.isEmpty else {
            isSaving = false
            return true
        }
        // Only send fields present after edit; deleted fields are in the mask but omitted from body.
        let bodyFields = after.filter { mask.contains($0.key) }
        do {
            let updated = try await service.patchDocument(
                projectID: projectID,
                databaseID: databaseID,
                documentPath: document.relativePath,
                fields: bodyFields,
                updateMask: mask,
                currentUpdateTime: document.updateTime
            )
            await audit.record(AuditEntry(
                accountID: nil,
                projectID: projectID,
                action: "firestore.patch",
                resource: document.relativePath,
                summary: "Patched \(mask.count) field(s)",
                reversible: false,
                beforeValue: beforeAfterSnapshot(before),
                afterValue: beforeAfterSnapshot(after)
            ))
            document = updated
            draftFields = updated.fields ?? [:]
            isSaving = false
            return true
        } catch APIError.preconditionFailed {
            conflictDetected = true
            error = .preconditionFailed(message: "This document changed since you loaded it.")
            isSaving = false
            return false
        } catch let api as APIError {
            error = api
            isSaving = false
            return false
        } catch {
            self.error = .transport(underlying: "unknown")
            isSaving = false
            return false
        }
    }

    func delete() async -> Bool {
        guard !writeInFlight else { return false }
        writeInFlight = true
        defer { writeInFlight = false }
        isDeleting = true
        error = nil
        do {
            try await service.deleteDocument(
                projectID: projectID,
                databaseID: databaseID,
                documentPath: document.relativePath,
                currentUpdateTime: document.updateTime
            )
            await audit.record(AuditEntry(
                accountID: nil,
                projectID: projectID,
                action: "firestore.delete",
                resource: document.relativePath,
                summary: "Deleted document",
                reversible: false,
                beforeValue: beforeAfterSnapshot(document.fields ?? [:]),
                afterValue: nil
            ))
            isDeleting = false
            return true
        } catch APIError.preconditionFailed {
            conflictDetected = true
            error = .preconditionFailed(message: "This document changed since you loaded it.")
            isDeleting = false
            return false
        } catch let api as APIError {
            error = api
            isDeleting = false
            return false
        } catch {
            self.error = .transport(underlying: "unknown")
            isDeleting = false
            return false
        }
    }

    private func beforeAfterSnapshot(_ fields: [String: FirestoreValue]) -> String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(fields),
              let string = String(data: data, encoding: .utf8) else { return nil }
        // Keep audit payloads small; never log raw secrets intentionally.
        return String(string.prefix(2_000))
    }
}
