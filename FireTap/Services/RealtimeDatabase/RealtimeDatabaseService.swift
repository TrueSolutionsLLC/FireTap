import Foundation

/// Firebase Realtime Database: instance discovery via the Database Management
/// API, plus JSON path CRUD against `https://{instance}.firebaseio.com`.
///
/// The default instance URL can also come from
/// `FirebaseProject.resources.realtimeDatabaseInstance` when Management listing
/// is unavailable — callers should fall back to that project resource field.
protocol RealtimeDatabaseService: Sendable {
    /// Lists RTDB instances via `firebasedatabase.googleapis.com`.
    /// - Parameter projectNumber: GCP project *number* (not project id).
    func listInstances(projectNumber: String) async throws -> [RealtimeDatabaseInstance]

    func getSnapshot(
        databaseURL: URL,
        path: String,
        shallow: Bool,
        timeout: TimeInterval
    ) async throws -> RealtimeDatabaseSnapshot

    func getJSON(
        databaseURL: URL,
        path: String,
        shallow: Bool,
        timeout: TimeInterval
    ) async throws -> Data

    func putJSON(
        databaseURL: URL,
        path: String,
        data: Data,
        ifMatch: String?,
        timeout: TimeInterval
    ) async throws -> Data

    func patchJSON(
        databaseURL: URL,
        path: String,
        data: Data,
        ifMatch: String?,
        timeout: TimeInterval
    ) async throws -> Data

    func deleteJSON(
        databaseURL: URL,
        path: String,
        ifMatch: String?,
        timeout: TimeInterval
    ) async throws
}

struct RealtimeDatabaseSnapshot: Sendable {
    let data: Data
    let etag: String?

    var text: String {
        String(data: data, encoding: .utf8) ?? "null"
    }

    var byteCount: Int { data.count }
}

struct LiveRealtimeDatabaseService: RealtimeDatabaseService {
    private let api: GoogleAPIClient
    private let managementBase = URL(static: "https://firebasedatabase.googleapis.com/v1beta")

    init(api: GoogleAPIClient) {
        self.api = api
    }

    func listInstances(projectNumber: String) async throws -> [RealtimeDatabaseInstance] {
        // locations/- lists across all regions.
        let url = managementBase.appendingPathComponent(
            "projects/\(projectNumber)/locations/-/instances"
        )
        var instances: [RealtimeDatabaseInstance] = []
        var pageToken: String?
        repeat {
            var query: [URLQueryItem] = []
            if let pageToken { query.append(URLQueryItem(name: "pageToken", value: pageToken)) }
            let response: ListDatabaseInstancesResponse = try await api.get(url: url, query: query)
            instances.append(contentsOf: response.instances ?? [])
            pageToken = response.nextPageToken
        } while pageToken != nil
        return instances
    }

    func getSnapshot(
        databaseURL: URL,
        path: String,
        shallow: Bool,
        timeout: TimeInterval
    ) async throws -> RealtimeDatabaseSnapshot {
        let url = try jsonURL(databaseURL: databaseURL, path: path)
        var query: [URLQueryItem] = []
        if shallow {
            query.append(URLQueryItem(name: "shallow", value: "true"))
        }
        let response = try await api.sendRaw(
            HTTPRequest(.get, url: url, query: query, timeout: timeout)
        )
        return RealtimeDatabaseSnapshot(data: response.data, etag: response.etag)
    }

    func getJSON(
        databaseURL: URL,
        path: String,
        shallow: Bool,
        timeout: TimeInterval
    ) async throws -> Data {
        try await getSnapshot(
            databaseURL: databaseURL,
            path: path,
            shallow: shallow,
            timeout: timeout
        ).data
    }

    func putJSON(
        databaseURL: URL,
        path: String,
        data: Data,
        ifMatch: String?,
        timeout: TimeInterval
    ) async throws -> Data {
        let url = try jsonURL(databaseURL: databaseURL, path: path)
        var headers: [String: String] = ["Content-Type": "application/json"]
        if let ifMatch {
            headers["If-Match"] = ifMatch
        }
        let response = try await api.sendRaw(
            HTTPRequest(.put, url: url, headers: headers, body: data, timeout: timeout)
        )
        return response.data
    }

    func patchJSON(
        databaseURL: URL,
        path: String,
        data: Data,
        ifMatch: String?,
        timeout: TimeInterval
    ) async throws -> Data {
        let url = try jsonURL(databaseURL: databaseURL, path: path)
        var headers: [String: String] = ["Content-Type": "application/json"]
        if let ifMatch {
            headers["If-Match"] = ifMatch
        }
        let response = try await api.sendRaw(
            HTTPRequest(.patch, url: url, headers: headers, body: data, timeout: timeout)
        )
        return response.data
    }

    func deleteJSON(
        databaseURL: URL,
        path: String,
        ifMatch: String?,
        timeout: TimeInterval
    ) async throws {
        let url = try jsonURL(databaseURL: databaseURL, path: path)
        var headers: [String: String] = [:]
        if let ifMatch {
            headers["If-Match"] = ifMatch
        }
        _ = try await api.sendVoid(
            HTTPRequest(.delete, url: url, headers: headers, timeout: timeout)
        )
    }

    /// Builds `https://{host}/{path}.json` from a database root URL.
    private func jsonURL(databaseURL: URL, path: String) throws -> URL {
        var root = databaseURL.absoluteString
        while root.hasSuffix("/") {
            root = String(root.dropLast())
        }
        let trimmed = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let urlString: String
        if trimmed.isEmpty {
            urlString = "\(root)/.json"
        } else {
            let encoded = trimmed
                .split(separator: "/")
                .map { segment -> String in
                    String(segment).addingPercentEncoding(withAllowedCharacters: .urlPathAllowedStrict) ?? String(segment)
                }
                .joined(separator: "/")
            urlString = "\(root)/\(encoded).json"
        }
        guard let url = URL(string: urlString) else {
            throw APIError.invalidResponse
        }
        return url
    }
}

// MARK: - Models

struct RealtimeDatabaseInstance: Codable, Sendable, Identifiable, Hashable {
    /// `projects/{number}/locations/{location}/instances/{databaseId}`
    let name: String?
    let project: String?
    let databaseUrl: String?
    let type: String?
    let state: String?

    var id: String { name ?? databaseUrl ?? "" }

    var databaseURL: URL? {
        guard let databaseUrl else { return nil }
        return URL(string: databaseUrl)
    }
}

struct ListDatabaseInstancesResponse: Codable, Sendable {
    let instances: [RealtimeDatabaseInstance]?
    let nextPageToken: String?
}

/// Builds a classic `.firebaseio.com` URL from a project resource instance id
/// when Management listing is not used.
enum RealtimeDatabaseURL {
    static func fromInstanceName(_ instance: String) -> URL? {
        let trimmed = instance.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if trimmed.hasPrefix("https://") {
            return URL(string: trimmed)
        }
        return URL(string: "https://\(trimmed).firebaseio.com")
    }
}

private extension CharacterSet {
    static let urlPathAllowedStrict: CharacterSet = {
        var set = CharacterSet.urlPathAllowed
        set.remove(charactersIn: ":/?#[]@!$&'()*+,;=")
        return set
    }()
}
