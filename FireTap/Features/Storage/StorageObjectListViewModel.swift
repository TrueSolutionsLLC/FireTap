import Foundation
import Observation

@MainActor
@Observable
final class StorageObjectListViewModel {
    let bucket: String
    let prefix: String

    var pageSize: Int = 50
    private(set) var folders: [String] = []
    private(set) var objects: [StorageObject] = []
    private(set) var isLoading = false
    private(set) var error: APIError?
    private(set) var nextPageToken: String?
    private(set) var hasLoadedOnce = false

    private let service: StorageService

    init(bucket: String, prefix: String, service: StorageService) {
        self.bucket = bucket
        self.prefix = prefix
        self.service = service
    }

    var reachedEnd: Bool { hasLoadedOnce && nextPageToken == nil }
    var isEmpty: Bool { hasLoadedOnce && folders.isEmpty && objects.isEmpty }

    func loadFirstPage() async {
        folders = []
        objects = []
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
            let response = try await service.listObjects(
                bucket: bucket,
                prefix: prefix,
                pageSize: pageSize,
                pageToken: isFirst ? nil : nextPageToken
            )
            // Folders (common prefixes) come back on the first page only.
            for folder in response.prefixes ?? [] where !folders.contains(folder) {
                folders.append(folder)
            }
            // The delimiter-based listing includes the prefix's own placeholder
            // object (equal to the prefix); hide it from the file list.
            let items = (response.items ?? []).filter { $0.name != prefix }
            objects.append(contentsOf: items)
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
