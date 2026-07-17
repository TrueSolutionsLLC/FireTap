import Foundation

/// Reads Cloud Storage buckets and objects via the documented Cloud Storage
/// JSON API. Uses a delimiter so browsing is folder-scoped and never lists an
/// entire bucket implicitly. Read-only in this build.
protocol StorageService: Sendable {
    func listBuckets(projectID: String) async throws -> [StorageBucket]
    func listObjects(
        bucket: String,
        prefix: String,
        pageSize: Int,
        pageToken: String?
    ) async throws -> ListObjectsResponse
}

struct LiveStorageService: StorageService {
    private let api: GoogleAPIClient
    private let base = URL(static: "https://storage.googleapis.com/storage/v1")

    init(api: GoogleAPIClient) {
        self.api = api
    }

    func listBuckets(projectID: String) async throws -> [StorageBucket] {
        let url = base.appendingPathComponent("b")
        var buckets: [StorageBucket] = []
        var pageToken: String?
        repeat {
            var query = [URLQueryItem(name: "project", value: projectID)]
            if let pageToken { query.append(URLQueryItem(name: "pageToken", value: pageToken)) }
            let response: ListBucketsResponse = try await api.get(url: url, query: query)
            buckets.append(contentsOf: response.items ?? [])
            pageToken = response.nextPageToken
        } while pageToken != nil
        return buckets.sorted { $0.name < $1.name }
    }

    func listObjects(
        bucket: String,
        prefix: String,
        pageSize: Int,
        pageToken: String?
    ) async throws -> ListObjectsResponse {
        let encodedBucket = bucket.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? bucket
        let url = base.appendingPathComponent("b/\(encodedBucket)/o")
        var query = [
            URLQueryItem(name: "delimiter", value: "/"),
            URLQueryItem(name: "maxResults", value: String(pageSize))
        ]
        if !prefix.isEmpty { query.append(URLQueryItem(name: "prefix", value: prefix)) }
        if let pageToken { query.append(URLQueryItem(name: "pageToken", value: pageToken)) }
        return try await api.get(url: url, query: query)
    }
}
