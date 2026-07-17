import Foundation

/// Reads (and, when unlocked, writes) Cloud Firestore data via the documented
/// Firestore REST API. Never loads an entire collection implicitly — callers
/// always pass an explicit page size.
protocol FirestoreService: Sendable {
    func listDatabases(projectID: String) async throws -> [FirestoreDatabase]
    func listCollectionIds(projectID: String, databaseID: String, parentDocumentPath: String?) async throws -> [String]
    func listDocuments(
        projectID: String,
        databaseID: String,
        collectionPath: String,
        pageSize: Int,
        pageToken: String?,
        orderBy: String?
    ) async throws -> ListDocumentsResponse
    func getDocument(projectID: String, databaseID: String, documentPath: String) async throws -> FirestoreDocument
}

struct LiveFirestoreService: FirestoreService {
    private let api: GoogleAPIClient
    private let base = URL(static: "https://firestore.googleapis.com/v1")

    init(api: GoogleAPIClient) {
        self.api = api
    }

    func listDatabases(projectID: String) async throws -> [FirestoreDatabase] {
        let url = base.appendingPathComponent("projects/\(projectID)/databases")
        let response: ListDatabasesResponse = try await api.get(url: url)
        return response.databases ?? []
    }

    func listCollectionIds(projectID: String, databaseID: String, parentDocumentPath: String?) async throws -> [String] {
        let documentsRoot = "projects/\(projectID)/databases/\(encode(databaseID))/documents"
        let target: String
        if let parentDocumentPath, !parentDocumentPath.isEmpty {
            target = "\(documentsRoot)/\(encodePath(parentDocumentPath)):listCollectionIds"
        } else {
            target = "\(documentsRoot):listCollectionIds"
        }
        guard let url = URL(string: "\(base.absoluteString)/\(target)") else { throw APIError.invalidResponse }
        var ids: [String] = []
        var pageToken: String?
        repeat {
            let body = try GoogleAPIClient.jsonBody(ListCollectionIdsRequest(pageSize: 200, pageToken: pageToken))
            let request = HTTPRequest(.post, url: url, body: body)
            let response: ListCollectionIdsResponse = try await api.send(request)
            ids.append(contentsOf: response.collectionIds ?? [])
            pageToken = response.nextPageToken
        } while pageToken != nil
        return ids.sorted()
    }

    func listDocuments(
        projectID: String,
        databaseID: String,
        collectionPath: String,
        pageSize: Int,
        pageToken: String?,
        orderBy: String?
    ) async throws -> ListDocumentsResponse {
        let path = "projects/\(projectID)/databases/\(encode(databaseID))/documents/\(encodePath(collectionPath))"
        guard let url = URL(string: "\(base.absoluteString)/\(path)") else { throw APIError.invalidResponse }
        var query = [URLQueryItem(name: "pageSize", value: String(pageSize))]
        if let pageToken { query.append(URLQueryItem(name: "pageToken", value: pageToken)) }
        if let orderBy { query.append(URLQueryItem(name: "orderBy", value: orderBy)) }
        return try await api.get(url: url, query: query)
    }

    func getDocument(projectID: String, databaseID: String, documentPath: String) async throws -> FirestoreDocument {
        let path = "projects/\(projectID)/databases/\(encode(databaseID))/documents/\(encodePath(documentPath))"
        guard let url = URL(string: "\(base.absoluteString)/\(path)") else { throw APIError.invalidResponse }
        return try await api.get(url: url)
    }

    // MARK: Path encoding

    /// Percent-encodes a single path segment (e.g. the database id "(default)").
    private func encode(_ segment: String) -> String {
        segment.addingPercentEncoding(withAllowedCharacters: .urlPathAllowedStrict) ?? segment
    }

    /// Percent-encodes each component of a multi-segment path, preserving "/".
    private func encodePath(_ path: String) -> String {
        path.split(separator: "/").map { encode(String($0)) }.joined(separator: "/")
    }
}

private struct ListCollectionIdsRequest: Encodable {
    let pageSize: Int
    let pageToken: String?
}

private extension CharacterSet {
    /// URL path-allowed set minus sub-delimiters that Firestore treats
    /// specially, so document ids with unusual characters stay safe.
    static let urlPathAllowedStrict: CharacterSet = {
        var set = CharacterSet.urlPathAllowed
        set.remove(charactersIn: ":/?#[]@!$&'()*+,;=")
        return set
    }()
}
