import Foundation

/// Cloud Resource Manager IAM — **read only**.
protocol IAMService: Sendable {
    func getIamPolicy(projectID: String) async throws -> ProjectIAMPolicy
}

struct LiveIAMService: IAMService {
    private let api: GoogleAPIClient
    private let base = URL(static: "https://cloudresourcemanager.googleapis.com/v1")

    init(api: GoogleAPIClient) {
        self.api = api
    }

    func getIamPolicy(projectID: String) async throws -> ProjectIAMPolicy {
        let url = base.appendingPathComponent("projects/\(projectID):getIamPolicy")
        let body = try GoogleAPIClient.jsonBody(GetIAMPolicyRequest())
        return try await api.send(HTTPRequest(.post, url: url, body: body))
    }
}

// MARK: - Models

struct ProjectIAMPolicy: Codable, Sendable, Equatable {
    let version: Int?
    let etag: String?
    let bindings: [IAMBinding]?
}

struct IAMBinding: Codable, Sendable, Equatable, Identifiable {
    let role: String?
    let members: [String]?
    let condition: IAMCondition?

    var id: String {
        let memberKey = (members ?? []).joined(separator: ",")
        return "\(role ?? "")|\(memberKey)"
    }
}

struct IAMCondition: Codable, Sendable, Equatable {
    let title: String?
    let description: String?
    let expression: String?
}

private struct GetIAMPolicyRequest: Encodable {
    // Empty body is valid for getIamPolicy; options can be added later.
}
