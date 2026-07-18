import Foundation

enum AuthLookupKey: Sendable, Equatable {
    case email(String)
    case phone(String)
    case uid(String)
}

protocol AuthService: Sendable {
    func listUsers(projectID: String, pageSize: Int, pageToken: String?) async throws -> DownloadAccountResponse
    func lookupUser(projectID: String, key: AuthLookupKey) async throws -> AuthUser?
    func countUsers(projectID: String) async throws -> Int?
    func updateUser(projectID: String, request: AuthUserUpdateRequest) async throws -> AuthUser
    func deleteUser(projectID: String, localID: String) async throws
    /// Sends a password-reset email via Identity Toolkit `accounts:sendOobCode`.
    /// FireTap never displays, stores, or generates passwords.
    func sendPasswordResetEmail(projectID: String, email: String) async throws
}

struct AuthUserUpdateRequest: Encodable, Sendable {
    var localId: String
    var email: String?
    var displayName: String?
    var phoneNumber: String?
    var disableUser: Bool?
    var customAttributes: String?
    var validSince: String?
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

    func updateUser(projectID: String, request: AuthUserUpdateRequest) async throws -> AuthUser {
        let url = base.appendingPathComponent("projects/\(projectID)/accounts:update")
        let body = try GoogleAPIClient.jsonBody(request)
        // Identity Toolkit returns the updated user object at the top level.
        return try await api.send(HTTPRequest(.post, url: url, body: body))
    }

    func deleteUser(projectID: String, localID: String) async throws {
        let url = base.appendingPathComponent("projects/\(projectID)/accounts:delete")
        let body = try GoogleAPIClient.jsonBody(DeleteRequest(localId: localID))
        _ = try await api.sendVoid(HTTPRequest(.post, url: url, body: body))
    }

    func sendPasswordResetEmail(projectID: String, email: String) async throws {
        let url = base.appendingPathComponent("projects/\(projectID)/accounts:sendOobCode")
        let body = try GoogleAPIClient.jsonBody(
            SendOobCodeRequest(requestType: "PASSWORD_RESET", email: email)
        )
        _ = try await api.sendVoid(HTTPRequest(.post, url: url, body: body))
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

private struct DeleteRequest: Encodable {
    let localId: String
}

private struct SendOobCodeRequest: Encodable {
    let requestType: String
    let email: String
}
