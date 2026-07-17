import Foundation

/// Reads the user's real Firebase projects via the Firebase Management API.
protocol ProjectsService: Sendable {
    /// Lists all projects the connected account can access, following
    /// pagination until exhausted.
    func listProjects() async throws -> [FirebaseProject]
    /// Fetches a single project's details.
    func project(id: String) async throws -> FirebaseProject
    /// Lists registered apps for a project.
    func listApps(projectID: String) async throws -> [FirebaseAppInfo]
}

/// Live implementation backed by `firebase.googleapis.com`.
struct LiveProjectsService: ProjectsService {
    private let api: GoogleAPIClient
    private let base = URL(static: "https://firebase.googleapis.com/v1beta1")

    init(api: GoogleAPIClient) {
        self.api = api
    }

    func listProjects() async throws -> [FirebaseProject] {
        var projects: [FirebaseProject] = []
        var pageToken: String?
        repeat {
            var query = [URLQueryItem(name: "pageSize", value: "100")]
            if let pageToken { query.append(URLQueryItem(name: "pageToken", value: pageToken)) }
            let response: ListProjectsResponse = try await api.get(
                url: base.appendingPathComponent("projects"),
                query: query
            )
            projects.append(contentsOf: response.results ?? [])
            pageToken = response.nextPageToken
        } while pageToken != nil
        return projects
    }

    func project(id: String) async throws -> FirebaseProject {
        try await api.get(url: base.appendingPathComponent("projects/\(id)"))
    }

    func listApps(projectID: String) async throws -> [FirebaseAppInfo] {
        var apps: [FirebaseAppInfo] = []
        var pageToken: String?
        repeat {
            var query = [URLQueryItem(name: "pageSize", value: "100")]
            if let pageToken { query.append(URLQueryItem(name: "pageToken", value: pageToken)) }
            let url = base.appendingPathComponent("projects/\(projectID):searchApps")
            let response: SearchAppsResponse = try await api.get(url: url, query: query)
            apps.append(contentsOf: response.apps ?? [])
            pageToken = response.nextPageToken
        } while pageToken != nil
        return apps
    }
}
