import Foundation

/// Firestore REST operations used by Phase 2. Reads always take an explicit
/// page size. Writes support update-time preconditions for concurrency.
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
    func runQuery(
        projectID: String,
        databaseID: String,
        parentDocumentPath: String?,
        query: FirestoreStructuredQuery,
        pageSize: Int
    ) async throws -> [FirestoreDocument]
    func createDocument(
        projectID: String,
        databaseID: String,
        collectionPath: String,
        documentID: String?,
        fields: [String: FirestoreValue]
    ) async throws -> FirestoreDocument
    func patchDocument(
        projectID: String,
        databaseID: String,
        documentPath: String,
        fields: [String: FirestoreValue],
        updateMask: [String],
        currentUpdateTime: String?
    ) async throws -> FirestoreDocument
    func deleteDocument(
        projectID: String,
        databaseID: String,
        documentPath: String,
        currentUpdateTime: String?
    ) async throws
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
            let response: ListCollectionIdsResponse = try await api.send(HTTPRequest(.post, url: url, body: body))
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

    func runQuery(
        projectID: String,
        databaseID: String,
        parentDocumentPath: String?,
        query: FirestoreStructuredQuery,
        pageSize: Int
    ) async throws -> [FirestoreDocument] {
        let documentsRoot = "projects/\(projectID)/databases/\(encode(databaseID))/documents"
        let target: String
        if let parentDocumentPath, !parentDocumentPath.isEmpty {
            target = "\(documentsRoot)/\(encodePath(parentDocumentPath)):runQuery"
        } else {
            target = "\(documentsRoot):runQuery"
        }
        guard let url = URL(string: "\(base.absoluteString)/\(target)") else { throw APIError.invalidResponse }
        var structured = query
        structured.limit = pageSize
        let body = try GoogleAPIClient.jsonBody(RunQueryRequest(structuredQuery: structured))
        let rows: [RunQueryRow] = try await api.send(HTTPRequest(.post, url: url, body: body))
        return rows.compactMap(\.document)
    }

    func createDocument(
        projectID: String,
        databaseID: String,
        collectionPath: String,
        documentID: String?,
        fields: [String: FirestoreValue]
    ) async throws -> FirestoreDocument {
        let path = "projects/\(projectID)/databases/\(encode(databaseID))/documents/\(encodePath(collectionPath))"
        guard let url = URL(string: "\(base.absoluteString)/\(path)") else { throw APIError.invalidResponse }
        var query: [URLQueryItem] = []
        if let documentID, !documentID.isEmpty {
            query.append(URLQueryItem(name: "documentId", value: documentID))
        }
        let body = try GoogleAPIClient.jsonBody(FirestoreWriteBody(fields: fields))
        return try await api.send(HTTPRequest(.post, url: url, query: query, body: body))
    }

    func patchDocument(
        projectID: String,
        databaseID: String,
        documentPath: String,
        fields: [String: FirestoreValue],
        updateMask: [String],
        currentUpdateTime: String?
    ) async throws -> FirestoreDocument {
        let path = "projects/\(projectID)/databases/\(encode(databaseID))/documents/\(encodePath(documentPath))"
        guard let url = URL(string: "\(base.absoluteString)/\(path)") else { throw APIError.invalidResponse }
        var query: [URLQueryItem] = updateMask.map {
            URLQueryItem(name: "updateMask.fieldPaths", value: $0)
        }
        if let currentUpdateTime {
            query.append(URLQueryItem(name: "currentDocument.updateTime", value: currentUpdateTime))
        }
        let body = try GoogleAPIClient.jsonBody(FirestoreWriteBody(fields: fields))
        return try await api.send(HTTPRequest(.patch, url: url, query: query, body: body))
    }

    func deleteDocument(
        projectID: String,
        databaseID: String,
        documentPath: String,
        currentUpdateTime: String?
    ) async throws {
        let path = "projects/\(projectID)/databases/\(encode(databaseID))/documents/\(encodePath(documentPath))"
        guard let url = URL(string: "\(base.absoluteString)/\(path)") else { throw APIError.invalidResponse }
        var query: [URLQueryItem] = []
        if let currentUpdateTime {
            query.append(URLQueryItem(name: "currentDocument.updateTime", value: currentUpdateTime))
        }
        _ = try await api.sendVoid(HTTPRequest(.delete, url: url, query: query))
    }

    private func encode(_ segment: String) -> String {
        segment.addingPercentEncoding(withAllowedCharacters: .urlPathAllowedStrict) ?? segment
    }

    private func encodePath(_ path: String) -> String {
        path.split(separator: "/").map { encode(String($0)) }.joined(separator: "/")
    }
}

// MARK: - Request / response DTOs

struct FirestoreWriteBody: Encodable, Sendable {
    let fields: [String: FirestoreValue]
}

struct ListCollectionIdsRequest: Encodable {
    let pageSize: Int
    let pageToken: String?
}

struct RunQueryRequest: Encodable {
    let structuredQuery: FirestoreStructuredQuery
}

struct RunQueryRow: Decodable, Sendable {
    let document: FirestoreDocument?
    let readTime: String?
}

/// Subset of Firestore structured query used by the mobile query builder.
struct FirestoreStructuredQuery: Codable, Sendable, Equatable {
    var from: [CollectionSelector]
    var `where`: Filter?
    var orderBy: [Order]?
    var limit: Int?

    struct CollectionSelector: Codable, Sendable, Equatable {
        var collectionId: String
        var allDescendants: Bool? = false
    }

    struct Order: Codable, Sendable, Equatable {
        var field: FieldReference
        var direction: String // ASCENDING / DESCENDING
    }

    struct FieldReference: Codable, Sendable, Equatable {
        var fieldPath: String
    }

    struct Filter: Codable, Sendable, Equatable {
        var fieldFilter: FieldFilter?
        var compositeFilter: CompositeFilter?
    }

    struct FieldFilter: Codable, Sendable, Equatable {
        var field: FieldReference
        var op: String
        var value: FirestoreValue
    }

    struct CompositeFilter: Codable, Sendable, Equatable {
        var op: String // AND / OR
        var filters: [Filter]
    }
}

private extension CharacterSet {
    static let urlPathAllowedStrict: CharacterSet = {
        var set = CharacterSet.urlPathAllowed
        set.remove(charactersIn: ":/?#[]@!$&'()*+,;=")
        return set
    }()
}
