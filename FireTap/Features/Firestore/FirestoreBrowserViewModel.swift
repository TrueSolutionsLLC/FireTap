import Foundation
import Observation

@MainActor
@Observable
final class FirestoreBrowserViewModel {
    let projectID: String
    var databaseID: String = "(default)"
    private(set) var phase: AsyncPhase<[String]> = .idle
    var searchText: String = ""

    private let service: FirestoreService

    init(projectID: String, service: FirestoreService) {
        self.projectID = projectID
        self.service = service
    }

    var displayedCollections: [String] {
        guard let ids = phase.value else { return [] }
        let needle = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        guard !needle.isEmpty else { return ids }
        return ids.filter { $0.lowercased().contains(needle) }
    }

    func load() async {
        if phase.value == nil { phase = .loading }
        do {
            let ids = try await service.listCollectionIds(
                projectID: projectID,
                databaseID: databaseID,
                parentDocumentPath: nil
            )
            phase = .loaded(ids)
        } catch let error as APIError {
            phase = .failed(error)
        } catch {
            phase = .failed(.transport(underlying: "unknown"))
        }
    }
}
