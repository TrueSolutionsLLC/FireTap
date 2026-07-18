import Foundation

/// Firebase Rules API — rulesets and releases for Firestore, Storage, and RTDB.
protocol RulesService: Sendable {
    func listRulesets(projectID: String, pageSize: Int, pageToken: String?) async throws -> ListRulesetsResponse
    func getRuleset(name: String) async throws -> Ruleset
    func listReleases(projectID: String, pageSize: Int, pageToken: String?) async throws -> ListRulesReleasesResponse
    func getRelease(projectID: String, releaseID: String) async throws -> RulesRelease
}

struct LiveRulesService: RulesService {
    private let api: GoogleAPIClient
    private let base = URL(static: "https://firebaserules.googleapis.com/v1")

    init(api: GoogleAPIClient) {
        self.api = api
    }

    func listRulesets(projectID: String, pageSize: Int, pageToken: String?) async throws -> ListRulesetsResponse {
        let url = base.appendingPathComponent("projects/\(projectID)/rulesets")
        var query = [URLQueryItem(name: "pageSize", value: String(pageSize))]
        if let pageToken { query.append(URLQueryItem(name: "pageToken", value: pageToken)) }
        return try await api.get(url: url, query: query)
    }

    func getRuleset(name: String) async throws -> Ruleset {
        guard let url = URL(string: base.absoluteString + "/" + name) else {
            throw APIError.transport(underlying: "invalid ruleset name")
        }
        return try await api.get(url: url)
    }

    func listReleases(projectID: String, pageSize: Int, pageToken: String?) async throws -> ListRulesReleasesResponse {
        let url = base.appendingPathComponent("projects/\(projectID)/releases")
        var query = [URLQueryItem(name: "pageSize", value: String(pageSize))]
        if let pageToken { query.append(URLQueryItem(name: "pageToken", value: pageToken)) }
        return try await api.get(url: url, query: query)
    }

    func getRelease(projectID: String, releaseID: String) async throws -> RulesRelease {
        let resource = "projects/\(projectID)/releases/\(releaseID)"
        guard let url = URL(string: base.absoluteString + "/" + resource) else {
            throw APIError.transport(underlying: "invalid release path")
        }
        return try await api.get(url: url)
    }
}

// MARK: - Models

struct Ruleset: Codable, Sendable, Identifiable, Hashable {
    let name: String?
    let createTime: String?
    let source: RulesSource?
    let metadata: RulesMetadata?

    var id: String { name ?? createTime ?? UUID().uuidString }

    var rulesetID: String {
        name?.split(separator: "/").last.map(String.init) ?? name ?? id
    }

    var rulesText: String? {
        source?.files?.map { file in
            let label = file.name ?? "rules"
            let body = file.content ?? ""
            return "// \(label)\n\(body)"
        }.joined(separator: "\n\n")
    }
}

struct RulesSource: Codable, Sendable, Hashable {
    let files: [RulesFile]?
}

struct RulesFile: Codable, Sendable, Hashable {
    let name: String?
    let content: String?
}

struct RulesMetadata: Codable, Sendable, Hashable {
    let services: [String]?
}

struct RulesRelease: Codable, Sendable, Identifiable, Hashable {
    let name: String?
    let rulesetName: String?
    let createTime: String?
    let updateTime: String?

    var id: String { name ?? rulesetName ?? createTime ?? UUID().uuidString }

    var releaseID: String {
        guard let name else { return id }
        if let range = name.range(of: "/releases/") {
            return String(name[range.upperBound...])
        }
        return name
    }
}

struct ListRulesetsResponse: Codable, Sendable {
    let rulesets: [Ruleset]?
    let nextPageToken: String?
}

struct ListRulesReleasesResponse: Codable, Sendable {
    let releases: [RulesRelease]?
    let nextPageToken: String?
}

/// Known Firebase Rules release names for common products.
enum RulesProduct: String, CaseIterable, Identifiable, Sendable {
    case firestore
    case storage
    case database

    var id: String { rawValue }

    var title: String {
        switch self {
        case .firestore: return "Cloud Firestore"
        case .storage: return "Cloud Storage"
        case .database: return "Realtime Database"
        }
    }

    func releaseName(projectID: String, storageBucket: String?, databaseInstance: String?) -> String {
        switch self {
        case .firestore:
            return "cloud.firestore"
        case .storage:
            let bucket = storageBucket ?? "\(projectID).appspot.com"
            return "firebase.storage/\(bucket)"
        case .database:
            let instance = databaseInstance ?? "\(projectID)-default-rtdb"
            return "firebase.database/\(instance)"
        }
    }
}
