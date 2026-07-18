import Foundation

/// Firebase Remote Config REST API — template get/publish with ETag, versions, rollback.
protocol RemoteConfigService: Sendable {
    func getTemplate(projectID: String) async throws -> RemoteConfigTemplateResult
    func publishTemplate(
        projectID: String,
        template: RemoteConfigTemplate,
        ifMatch: String
    ) async throws -> RemoteConfigTemplateResult
    func listVersions(projectID: String, pageSize: Int, pageToken: String?) async throws -> ListRemoteConfigVersionsResponse
    func rollback(projectID: String, versionNumber: String) async throws -> RemoteConfigTemplateResult
}

struct LiveRemoteConfigService: RemoteConfigService {
    private let api: GoogleAPIClient
    private let base = URL(static: "https://firebaseremoteconfig.googleapis.com/v1")

    init(api: GoogleAPIClient) {
        self.api = api
    }

    func getTemplate(projectID: String) async throws -> RemoteConfigTemplateResult {
        let url = base.appendingPathComponent("projects/\(projectID)/remoteConfig")
        let response = try await api.sendRaw(HTTPRequest(.get, url: url))
        let template = try decodeTemplate(from: response.data)
        return RemoteConfigTemplateResult(template: template, etag: response.etag)
    }

    func publishTemplate(
        projectID: String,
        template: RemoteConfigTemplate,
        ifMatch: String
    ) async throws -> RemoteConfigTemplateResult {
        let url = base.appendingPathComponent("projects/\(projectID)/remoteConfig")
        let body = try GoogleAPIClient.jsonBody(template)
        let response = try await api.sendRaw(
            HTTPRequest(
                .put,
                url: url,
                headers: [
                    "Content-Type": "application/json",
                    "If-Match": ifMatch
                ],
                body: body
            )
        )
        let published = try decodeTemplate(from: response.data)
        return RemoteConfigTemplateResult(template: published, etag: response.etag)
    }

    func listVersions(
        projectID: String,
        pageSize: Int,
        pageToken: String?
    ) async throws -> ListRemoteConfigVersionsResponse {
        let url = base.appendingPathComponent("projects/\(projectID)/remoteConfig:listVersions")
        var query = [URLQueryItem(name: "pageSize", value: String(pageSize))]
        if let pageToken { query.append(URLQueryItem(name: "pageToken", value: pageToken)) }
        return try await api.get(url: url, query: query)
    }

    func rollback(projectID: String, versionNumber: String) async throws -> RemoteConfigTemplateResult {
        let url = base.appendingPathComponent("projects/\(projectID)/remoteConfig:rollback")
        let body = try GoogleAPIClient.jsonBody(RollbackRequest(versionNumber: versionNumber))
        let response = try await api.sendRaw(
            HTTPRequest(.post, url: url, headers: ["Content-Type": "application/json"], body: body)
        )
        let template = try decodeTemplate(from: response.data)
        return RemoteConfigTemplateResult(template: template, etag: response.etag)
    }

    private func decodeTemplate(from data: Data) throws -> RemoteConfigTemplate {
        do {
            return try JSONDecoder().decode(RemoteConfigTemplate.self, from: data)
        } catch {
            throw APIError.decoding(context: "RemoteConfigTemplate")
        }
    }
}

// MARK: - Models

struct RemoteConfigTemplateResult: Sendable, Equatable {
    let template: RemoteConfigTemplate
    let etag: String?
}

/// Simplified Remote Config template (parameters + optional version metadata).
struct RemoteConfigTemplate: Codable, Sendable, Equatable {
    var parameters: [String: RemoteConfigParameter]?
    var parameterGroups: [String: RemoteConfigParameterGroup]?
    var conditions: [RemoteConfigCondition]?
    var version: RemoteConfigVersion?
}

struct RemoteConfigParameter: Codable, Sendable, Equatable {
    var defaultValue: RemoteConfigParameterValue?
    var conditionalValues: [String: RemoteConfigParameterValue]?
    var description: String?
    var valueType: String?
}

struct RemoteConfigParameterValue: Codable, Sendable, Equatable {
    var value: String?
    var useInAppDefault: Bool?
}

struct RemoteConfigParameterGroup: Codable, Sendable, Equatable {
    var description: String?
    var parameters: [String: RemoteConfigParameter]?
}

struct RemoteConfigCondition: Codable, Sendable, Equatable {
    var name: String?
    var expression: String?
    var tagColor: String?
}

struct RemoteConfigVersion: Codable, Sendable, Equatable, Identifiable {
    var versionNumber: String?
    var updateTime: String?
    var updateUser: RemoteConfigUser?
    var description: String?
    var updateOrigin: String?
    var updateType: String?

    var id: String { versionNumber ?? updateTime ?? description ?? "" }
}

struct RemoteConfigUser: Codable, Sendable, Equatable {
    var email: String?
    var name: String?
    var imageUrl: String?
}

struct ListRemoteConfigVersionsResponse: Codable, Sendable {
    let versions: [RemoteConfigVersion]?
    let nextPageToken: String?
}

private struct RollbackRequest: Encodable {
    let versionNumber: String
}
