import Foundation

/// Firebase Extensions API — installed extension instances.
protocol ExtensionsService: Sendable {
    func listInstances(projectID: String, pageSize: Int, pageToken: String?) async throws -> ListExtensionInstancesResponse
}

struct LiveExtensionsService: ExtensionsService {
    private let api: GoogleAPIClient
    private let base = URL(static: "https://firebaseextensions.googleapis.com/v1beta")

    init(api: GoogleAPIClient) {
        self.api = api
    }

    func listInstances(projectID: String, pageSize: Int, pageToken: String?) async throws -> ListExtensionInstancesResponse {
        let url = base.appendingPathComponent("projects/\(projectID)/instances")
        var query = [URLQueryItem(name: "pageSize", value: String(pageSize))]
        if let pageToken { query.append(URLQueryItem(name: "pageToken", value: pageToken)) }
        return try await api.get(url: url, query: query)
    }
}

// MARK: - Models

struct ExtensionInstance: Codable, Sendable, Identifiable, Hashable {
    let name: String?
    let state: String?
    let createTime: String?
    let updateTime: String?
    let config: ExtensionConfig?
    let extensionRef: String?
    let extensionVersion: String?

    var id: String { name ?? extensionRef ?? createTime ?? UUID().uuidString }

    var instanceID: String {
        name?.split(separator: "/").last.map(String.init) ?? id
    }

    var extensionDisplayName: String {
        extensionRef?.split(separator: "/").last.map(String.init) ?? extensionRef ?? "Extension"
    }
}

struct ExtensionConfig: Codable, Sendable, Hashable {
    let params: [String: String]?
    let allowedEventTypes: [String]?
    let eventarcChannel: String?
}

struct ListExtensionInstancesResponse: Codable, Sendable {
    let instances: [ExtensionInstance]?
    let nextPageToken: String?
}
