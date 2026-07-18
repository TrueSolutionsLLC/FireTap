import Foundation

/// A Firebase project as returned by the Firebase Management API
/// (`firebase.googleapis.com/v1beta1/projects`).
struct FirebaseProject: Decodable, Sendable, Identifiable, Hashable {
    let projectId: String
    let projectNumber: String?
    let displayName: String?
    let state: String?
    let resources: Resources?

    var id: String { projectId }

    struct Resources: Decodable, Sendable, Hashable {
        let hostingSite: String?
        let realtimeDatabaseInstance: String?
        let storageBucket: String?
        let locationId: String?
    }

    var name: String {
        if let displayName, !displayName.isEmpty { return displayName }
        return projectId
    }

    /// True when the Management API reports an ACTIVE lifecycle state.
    var isActive: Bool {
        (state ?? "ACTIVE").uppercased() == "ACTIVE"
    }

    /// Human-readable lifecycle state for list rows.
    var lifecycleDisplay: String {
        let raw = (state ?? "ACTIVE").uppercased()
        switch raw {
        case "ACTIVE": return "Active"
        case "DELETED": return "Deleted"
        case "DELETE_REQUESTED": return "Delete requested"
        default: return raw.capitalized
        }
    }

    /// Best-effort region string for display, if the project has a resource
    /// location set. Absent until the user has selected a default GCP location.
    var regionDisplay: String? {
        resources?.locationId
    }
}

/// Paginated list response.
struct ListProjectsResponse: Decodable, Sendable {
    let results: [FirebaseProject]?
    let nextPageToken: String?
}

/// A registered app within a Firebase project (from `:searchApps`).
struct FirebaseAppInfo: Decodable, Sendable, Identifiable, Hashable {
    let appId: String
    let displayName: String?
    let platform: String?

    var id: String { appId }
}

struct SearchAppsResponse: Decodable, Sendable {
    let apps: [FirebaseAppInfo]?
    let nextPageToken: String?
}
