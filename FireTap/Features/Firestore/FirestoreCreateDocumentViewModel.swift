import Foundation
import Observation

@MainActor
@Observable
final class FirestoreCreateDocumentViewModel {
    enum InputMode: String, CaseIterable, Identifiable {
        case simple = "Simple"
        case json = "JSON"

        var id: String { rawValue }
    }

    let projectID: String
    let databaseID: String
    let collectionPath: String

    var documentID = ""
    var inputMode: InputMode = .simple
    var fieldsText = ""
    private(set) var isCreating = false
    private(set) var error: APIError?
    private(set) var parseError: String?

    private let service: FirestoreService
    private let usage: SessionUsage
    private let audit: AuditLogging
    private var writeInFlight = false

    init(
        projectID: String,
        databaseID: String,
        collectionPath: String,
        service: FirestoreService,
        usage: SessionUsage,
        audit: AuditLogging
    ) {
        self.projectID = projectID
        self.databaseID = databaseID
        self.collectionPath = collectionPath
        self.service = service
        self.usage = usage
        self.audit = audit
    }

    var trimmedDocumentID: String? {
        let trimmed = documentID.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    func parsedFields() -> [String: FirestoreValue]? {
        parseError = nil
        do {
            switch inputMode {
            case .simple:
                return try FirestoreFieldsParser.parseSimple(fieldsText)
            case .json:
                return try FirestoreFieldsParser.parseJSON(fieldsText)
            }
        } catch let parserError as FirestoreFieldsParserError {
            parseError = parserError.localizedDescription
            return nil
        } catch {
            parseError = error.localizedDescription
            return nil
        }
    }

    func create() async -> FirestoreDocument? {
        guard !writeInFlight else { return nil }
        guard let fields = parsedFields() else { return nil }
        writeInFlight = true
        defer { writeInFlight = false }
        isCreating = true
        error = nil
        do {
            let created = try await service.createDocument(
                projectID: projectID,
                databaseID: databaseID,
                collectionPath: collectionPath,
                documentID: trimmedDocumentID,
                fields: fields
            )
            usage.addWrites(1)
            await audit.record(AuditEntry(
                accountID: nil,
                projectID: projectID,
                action: "firestore.create",
                resource: created.relativePath,
                summary: "Created document with \(fields.count) field(s)",
                reversible: false,
                beforeValue: nil,
                afterValue: auditSnapshot(fields)
            ))
            isCreating = false
            return created
        } catch let api as APIError {
            error = api
            isCreating = false
            return nil
        } catch {
            self.error = .transport(underlying: "unknown")
            isCreating = false
            return nil
        }
    }

    private func auditSnapshot(_ fields: [String: FirestoreValue]) -> String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(fields),
              let string = String(data: data, encoding: .utf8) else { return nil }
        return String(string.prefix(2_000))
    }
}
