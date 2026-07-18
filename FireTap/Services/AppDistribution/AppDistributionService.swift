import Foundation

/// Firebase App Distribution API — apps, releases, and tester groups.
protocol AppDistributionService: Sendable {
    func listApps(projectNumber: String, pageSize: Int, pageToken: String?) async throws -> ListAppDistributionAppsResponse
    func listReleases(
        projectNumber: String,
        appID: String,
        pageSize: Int,
        pageToken: String?
    ) async throws -> ListAppDistributionReleasesResponse
    func listGroups(projectNumber: String, pageSize: Int, pageToken: String?) async throws -> ListAppDistributionGroupsResponse
}

struct LiveAppDistributionService: AppDistributionService {
    private let api: GoogleAPIClient
    private let base = URL(static: "https://firebaseappdistribution.googleapis.com/v1")

    init(api: GoogleAPIClient) {
        self.api = api
    }

    func listApps(projectNumber: String, pageSize: Int, pageToken: String?) async throws -> ListAppDistributionAppsResponse {
        let url = base.appendingPathComponent("projects/\(projectNumber)/apps")
        var query = [URLQueryItem(name: "pageSize", value: String(pageSize))]
        if let pageToken { query.append(URLQueryItem(name: "pageToken", value: pageToken)) }
        return try await api.get(url: url, query: query)
    }

    func listReleases(
        projectNumber: String,
        appID: String,
        pageSize: Int,
        pageToken: String?
    ) async throws -> ListAppDistributionReleasesResponse {
        let parent = "projects/\(projectNumber)/apps/\(appID)"
        let url = base.appendingPathComponent("\(parent)/releases")
        var query = [URLQueryItem(name: "pageSize", value: String(pageSize))]
        if let pageToken { query.append(URLQueryItem(name: "pageToken", value: pageToken)) }
        return try await api.get(url: url, query: query)
    }

    func listGroups(projectNumber: String, pageSize: Int, pageToken: String?) async throws -> ListAppDistributionGroupsResponse {
        let url = base.appendingPathComponent("projects/\(projectNumber)/groups")
        var query = [URLQueryItem(name: "pageSize", value: String(pageSize))]
        if let pageToken { query.append(URLQueryItem(name: "pageToken", value: pageToken)) }
        return try await api.get(url: url, query: query)
    }
}

// MARK: - Models

struct AppDistributionApp: Codable, Sendable, Identifiable, Hashable {
    let name: String?
    let appId: String?
    let displayName: String?
    let contactInfo: String?
    let expireTime: String?

    var id: String { appId ?? name ?? displayName ?? UUID().uuidString }

    var resolvedAppID: String {
        if let appId, !appId.isEmpty { return appId }
        return name?.split(separator: "/").last.map(String.init) ?? id
    }
}

struct AppDistributionRelease: Codable, Sendable, Identifiable, Hashable {
    let name: String?
    let displayVersion: String?
    let buildVersion: String?
    let createTime: String?
    let releaseNotes: AppDistributionReleaseNotes?
    let binaryDownloadUri: String?

    var id: String { name ?? "\(displayVersion ?? "")-\(buildVersion ?? "")" }

    var releaseID: String {
        name?.split(separator: "/").last.map(String.init) ?? id
    }
}

struct AppDistributionReleaseNotes: Codable, Sendable, Hashable {
    let text: String?
}

struct AppDistributionGroup: Codable, Sendable, Identifiable, Hashable {
    let name: String?
    let displayName: String?
    let testerCount: Int?
    let releaseCount: Int?
    let inviteLinkCount: Int?

    var id: String { name ?? displayName ?? UUID().uuidString }

    var groupID: String {
        name?.split(separator: "/").last.map(String.init) ?? displayName ?? id
    }
}

struct ListAppDistributionAppsResponse: Codable, Sendable {
    let apps: [AppDistributionApp]?
    let nextPageToken: String?
}

struct ListAppDistributionReleasesResponse: Codable, Sendable {
    let releases: [AppDistributionRelease]?
    let nextPageToken: String?
}

struct ListAppDistributionGroupsResponse: Codable, Sendable {
    let groups: [AppDistributionGroup]?
    let nextPageToken: String?
}
