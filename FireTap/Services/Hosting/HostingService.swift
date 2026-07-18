import Foundation

/// Firebase Hosting API — sites, channels, and releases.
protocol HostingService: Sendable {
    func listSites(projectID: String) async throws -> [HostingSite]
    func listChannels(siteID: String) async throws -> [HostingChannel]
    func listReleases(siteID: String, channelID: String, pageSize: Int, pageToken: String?) async throws -> ListHostingReleasesResponse
}

struct LiveHostingService: HostingService {
    private let api: GoogleAPIClient
    private let base = URL(static: "https://firebasehosting.googleapis.com/v1beta1")

    init(api: GoogleAPIClient) {
        self.api = api
    }

    func listSites(projectID: String) async throws -> [HostingSite] {
        let url = base.appendingPathComponent("projects/\(projectID)/sites")
        var sites: [HostingSite] = []
        var pageToken: String?
        repeat {
            var query: [URLQueryItem] = []
            if let pageToken { query.append(URLQueryItem(name: "pageToken", value: pageToken)) }
            let response: ListHostingSitesResponse = try await api.get(url: url, query: query)
            sites.append(contentsOf: response.sites ?? [])
            pageToken = response.nextPageToken
        } while pageToken != nil
        return sites
    }

    func listChannels(siteID: String) async throws -> [HostingChannel] {
        let url = base.appendingPathComponent("sites/\(siteID)/channels")
        var channels: [HostingChannel] = []
        var pageToken: String?
        repeat {
            var query: [URLQueryItem] = []
            if let pageToken { query.append(URLQueryItem(name: "pageToken", value: pageToken)) }
            let response: ListHostingChannelsResponse = try await api.get(url: url, query: query)
            channels.append(contentsOf: response.channels ?? [])
            pageToken = response.nextPageToken
        } while pageToken != nil
        return channels
    }

    func listReleases(
        siteID: String,
        channelID: String,
        pageSize: Int,
        pageToken: String?
    ) async throws -> ListHostingReleasesResponse {
        let url = base.appendingPathComponent("sites/\(siteID)/channels/\(channelID)/releases")
        var query = [URLQueryItem(name: "pageSize", value: String(pageSize))]
        if let pageToken { query.append(URLQueryItem(name: "pageToken", value: pageToken)) }
        return try await api.get(url: url, query: query)
    }
}

// MARK: - Models

struct HostingSite: Codable, Sendable, Identifiable, Hashable {
    /// `projects/{project}/sites/{siteId}` or legacy `sites/{siteId}`.
    let name: String?
    let defaultUrl: String?
    let appId: String?
    let type: String?

    var id: String { siteID }

    var siteID: String {
        name?.split(separator: "/").last.map(String.init) ?? name ?? ""
    }
}

struct HostingChannel: Codable, Sendable, Identifiable, Hashable {
    let name: String?
    let url: String?
    let createTime: String?
    let updateTime: String?
    let retainedReleaseCount: Int?
    let expireTime: String?

    var id: String { channelID }

    var channelID: String {
        name?.split(separator: "/").last.map(String.init) ?? name ?? ""
    }
}

struct HostingRelease: Codable, Sendable, Identifiable, Hashable {
    let name: String?
    let version: HostingVersionRef?
    let type: String?
    let releaseTime: String?
    let message: String?

    var id: String { name ?? releaseTime ?? "" }
}

struct HostingVersionRef: Codable, Sendable, Hashable {
    let name: String?
    let status: String?
}

struct ListHostingSitesResponse: Codable, Sendable {
    let sites: [HostingSite]?
    let nextPageToken: String?
}

struct ListHostingChannelsResponse: Codable, Sendable {
    let channels: [HostingChannel]?
    let nextPageToken: String?
}

struct ListHostingReleasesResponse: Codable, Sendable {
    let releases: [HostingRelease]?
    let nextPageToken: String?
}
