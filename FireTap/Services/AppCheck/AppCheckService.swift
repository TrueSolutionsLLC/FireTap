import Foundation

/// Firebase App Check Admin API.
///
/// Service enforcement configs are publicly listable via
/// `firebaseappcheck.googleapis.com`. There is **no** public browse endpoint
/// that lists every app's App Check provider config without already knowing
/// app IDs — `listApps` therefore throws `.notFound` so the UI can show
/// unavailable rather than inventing data. Use `ProjectsService.listApps` for
/// registered Firebase apps, then fetch per-app configs when an ID is known.
protocol AppCheckService: Sendable {
    func listServices(projectID: String) async throws -> [AppCheckServiceConfig]
    func getService(projectID: String, serviceID: String) async throws -> AppCheckServiceConfig

    /// No public App Check "list apps" browse API. Always throws
    /// `APIError.notFound` — UI must show unavailable.
    func listApps(projectID: String) async throws -> [AppCheckAppSummary]
}

struct LiveAppCheckService: AppCheckService {
    private let api: GoogleAPIClient
    private let base = URL(static: "https://firebaseappcheck.googleapis.com/v1")

    init(api: GoogleAPIClient) {
        self.api = api
    }

    func listServices(projectID: String) async throws -> [AppCheckServiceConfig] {
        let url = base.appendingPathComponent("projects/\(projectID)/services")
        var services: [AppCheckServiceConfig] = []
        var pageToken: String?
        repeat {
            var query: [URLQueryItem] = []
            if let pageToken { query.append(URLQueryItem(name: "pageToken", value: pageToken)) }
            let response: ListAppCheckServicesResponse = try await api.get(url: url, query: query)
            services.append(contentsOf: response.services ?? [])
            pageToken = response.nextPageToken
        } while pageToken != nil
        return services
    }

    func getService(projectID: String, serviceID: String) async throws -> AppCheckServiceConfig {
        let url = base.appendingPathComponent("projects/\(projectID)/services/\(serviceID)")
        return try await api.get(url: url)
    }

    func listApps(projectID: String) async throws -> [AppCheckAppSummary] {
        // App Check does not expose a project-wide apps list for provider configs.
        // Callers must use ProjectsService for app IDs; UI should show unavailable.
        _ = projectID
        throw APIError.notFound(
            message: "App Check app configs are not browsable via a public list API. UI must show unavailable."
        )
    }
}

// MARK: - Models

struct AppCheckServiceConfig: Codable, Sendable, Identifiable, Hashable {
    /// `projects/{project}/services/{service_id}`
    let name: String?
    let enforcementMode: String?
    let etag: String?

    var id: String { name ?? "" }

    var serviceID: String {
        name?.split(separator: "/").last.map(String.init) ?? name ?? ""
    }
}

/// Type retained for protocol completeness. The live client never returns
/// instances — `listApps` throws `.notFound` because no public browse API exists.
struct AppCheckAppSummary: Codable, Sendable, Identifiable, Hashable {
    let appId: String
    var id: String { appId }
}

struct ListAppCheckServicesResponse: Codable, Sendable {
    let services: [AppCheckServiceConfig]?
    let nextPageToken: String?
}
