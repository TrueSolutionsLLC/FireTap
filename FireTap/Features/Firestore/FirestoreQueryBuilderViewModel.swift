import Foundation
import Observation

@MainActor
@Observable
final class FirestoreQueryBuilderViewModel {
    let projectID: String
    let databaseID: String
    let collectionID: String
    let parentDocumentPath: String?

    var filterField = ""
    var filterOp: FirestoreQueryOperator = .equal
    var filterValue = ""
    var filterValueKind: SavedQueryFilterValueKind = .string
    var orderField = ""
    var descending = false
    var limit: Int = 25
    private(set) var isRunning = false
    private(set) var error: APIError?
    private(set) var results: [FirestoreDocument] = []
    private(set) var lastRequestedCount = 0
    private(set) var hasRunOnce = false

    private let service: FirestoreService
    private let usage: SessionUsage

    init(
        projectID: String,
        databaseID: String,
        collectionContext: FirestoreCollectionContext,
        service: FirestoreService,
        usage: SessionUsage
    ) {
        self.projectID = projectID
        self.databaseID = databaseID
        self.collectionID = collectionContext.collectionID
        self.parentDocumentPath = collectionContext.parentDocumentPath
        self.service = service
        self.usage = usage
    }

    var sessionReads: Int { usage.firestoreReads }
    var filterEnabled: Bool {
        !filterField.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !filterValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func buildStructuredQuery() -> FirestoreStructuredQuery {
        makeSavedQuery(title: "").toStructuredQuery()
    }

    func makeSavedQuery(title: String) -> SavedFirestoreQuery {
        let trimmedField = filterField.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedValue = filterValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedOrder = orderField.trimmingCharacters(in: .whitespacesAndNewlines)
        return SavedFirestoreQuery.make(
            title: title,
            collectionID: collectionID,
            fieldPath: filterEnabled ? trimmedField : nil,
            op: filterEnabled ? filterOp.rawValue : nil,
            stringValue: filterEnabled ? trimmedValue : nil,
            filterValueKind: filterEnabled ? filterValueKind : nil,
            orderField: trimmedOrder.isEmpty ? nil : trimmedOrder,
            descending: descending,
            limit: limit
        )
    }

    func applySaved(_ saved: SavedFirestoreQuery) {
        filterField = saved.fieldPath ?? ""
        filterOp = FirestoreQueryOperator(rawValue: saved.op ?? "") ?? .equal
        filterValue = saved.stringValue ?? ""
        filterValueKind = saved.filterValueKind ?? .string
        orderField = saved.orderField ?? ""
        descending = saved.descending
        limit = saved.limit
    }

    func runQuery() async {
        isRunning = true
        error = nil
        lastRequestedCount = limit
        do {
            let docs = try await service.runQuery(
                projectID: projectID,
                databaseID: databaseID,
                parentDocumentPath: parentDocumentPath,
                query: buildStructuredQuery(),
                pageSize: limit
            )
            usage.addReads(docs.count)
            results = docs
            hasRunOnce = true
        } catch let api as APIError {
            error = api
        } catch {
            self.error = .transport(underlying: "unknown")
        }
        isRunning = false
    }
}
