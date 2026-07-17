import Foundation

/// How to search the user directory when looking up a single account.
enum AuthLookupKey: Sendable, Equatable {
    case email(String)
    case phone(String)
    case uid(String)
}

/// Reads Firebase Authentication users via the documented Identity Toolkit
/// Admin API. Reads only for now — write operations (create/update/disable/
/// delete) are intentionally not exposed until they can be verified against a
/// real non-production project, so the UI never shows a working-looking control
/// for an unverified operation.
protocol AuthService: Sendable {
    /// One page of accounts via `accounts:batchGet` (cursor pagination).
    func listUsers(projectID: String, pageSize: Int, pageToken: String?) async throws -> DownloadAccountResponse
    /// A single account via `accounts:lookup`.
    func lookupUser(projectID: String, key: AuthLookupKey) async throws -> AuthUser?
    /// Total account count via `accounts:query` (no user bodies fetched).
    func countUsers(projectID: String) async throws -> Int?
}

struct LiveAuthService: AuthService {
    private let api: GoogleAPIClient
    private let base = URL(static: "https://identitytoolkit.googleapis.com/v1")

    init(api: GoogleAPIClient) {
        self.api = api
    }

    func listUsers(projectID: String, pageSize: Int, pageToken: String?) async throws -> DownloadAccountResponse {
        let url = base.appendingPathComponent("projects/\(projectID)/accounts:batchGet")
        var query = [URLQueryItem(name: "maxResults", value: String(pageSize))]
        if let pageToken, !pageToken.isEmpty {
            query.append(URLQueryItem(name: "nextPageToken", value: pageToken))
        }
        return try await api.get(url: url, query: query)
    }

    func lookupUser(projectID: String, key: AuthLookupKey) async throws -> AuthUser? {
        let url = base.appendingPathComponent("projects/\(projectID)/accounts:lookup")
        let body = try GoogleAPIClient.jsonBody(LookupRequest(key: key))
        do {
            let response: LookupAccountResponse = try await api.send(HTTPRequest(.post, url: url, body: body))
            return response.users?.first
        } catch APIError.notFound {
            return nil
        }
    }

    func countUsers(projectID: String) async throws -> Int? {
        let url = base.appendingPathComponent("projects/\(projectID)/accounts:query")
        let body = try GoogleAPIClient.jsonBody(QueryRequest(returnUserInfo: false))
        let response: QueryAccountResponse = try await api.send(HTTPRequest(.post, url: url, body: body))
        return response.count
    }
}

private struct LookupRequest: Encodable {
    let email: [String]?
    let phoneNumber: [String]?
    let localId: [String]?

    init(key: AuthLookupKey) {
        switch key {
        case .email(let value): email = [value]; phoneNumber = nil; localId = nil
        case .phone(let value): email = nil; phoneNumber = [value]; localId = nil
        case .uid(let value): email = nil; phoneNumber = nil; localId = [value]
        }
    }
}

private struct QueryRequest: Encodable {
    let returnUserInfo: Bool
}
