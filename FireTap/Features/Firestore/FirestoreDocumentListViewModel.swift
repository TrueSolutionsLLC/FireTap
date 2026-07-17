import Foundation
import Observation

@MainActor
@Observable
final class FirestoreDocumentListViewModel {
    let projectID: String
    let databaseID: String
    let collectionPath: String

    /// Explicit page size — the app never loads an entire collection at once.
    var pageSize: Int = 25
    private(set) var documents: [FirestoreDocument] = []
    private(set) var isLoading = false
    private(set) var error: APIError?
    private(set) var nextPageToken: String?
    private(set) var hasLoadedOnce = false
    private(set) var lastPageCount = 0

    private let service: FirestoreService
    private let usage: SessionUsage

    init(projectID: String, databaseID: String, collectionPath: String, service: FirestoreService, usage: SessionUsage) {
        self.projectID = projectID
        self.databaseID = databaseID
        self.collectionPath = collectionPath
        self.service = service
        self.usage = usage
    }

    var reachedEnd: Bool { hasLoadedOnce && nextPageToken == nil }
    var sessionReads: Int { usage.firestoreReads }
    var willBeLargeRead: Bool { usage.isLargeRead(pageSize: pageSize) }

    func loadFirstPage() async {
        documents = []
        nextPageToken = nil
        hasLoadedOnce = false
        await loadPage(isFirst: true)
    }

    func loadNextPage() async {
        guard !isLoading, !reachedEnd else { return }
        await loadPage(isFirst: false)
    }

    private func loadPage(isFirst: Bool) async {
        isLoading = true
        error = nil
        do {
            let response = try await service.listDocuments(
                projectID: projectID,
                databaseID: databaseID,
                collectionPath: collectionPath,
                pageSize: pageSize,
                pageToken: isFirst ? nil : nextPageToken,
                orderBy: nil
            )
            let docs = response.documents ?? []
            // Viewing documents creates billable reads — count them honestly.
            usage.addReads(docs.count)
            lastPageCount = docs.count
            documents.append(contentsOf: docs)
            nextPageToken = response.nextPageToken
            hasLoadedOnce = true
        } catch let apiError as APIError {
            error = apiError
        } catch {
            self.error = .transport(underlying: "unknown")
        }
        isLoading = false
    }
}
