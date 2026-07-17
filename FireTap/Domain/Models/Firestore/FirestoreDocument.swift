import Foundation

/// A Firestore document in REST format.
struct FirestoreDocument: Codable, Sendable, Identifiable, Equatable {
    /// Full resource name: `projects/P/databases/D/documents/coll/doc`.
    let name: String
    let fields: [String: FirestoreValue]?
    let createTime: String?
    let updateTime: String?

    var id: String { name }

    /// Last path component (the document id).
    var documentID: String {
        name.split(separator: "/").last.map(String.init) ?? name
    }

    /// The collection/subcollection path relative to `.../documents/`.
    var relativePath: String {
        guard let range = name.range(of: "/documents/") else { return name }
        return String(name[range.upperBound...])
    }
}

/// Response for a documents list call.
struct ListDocumentsResponse: Decodable, Sendable {
    let documents: [FirestoreDocument]?
    let nextPageToken: String?
}

/// Response for `:listCollectionIds`.
struct ListCollectionIdsResponse: Decodable, Sendable {
    let collectionIds: [String]?
    let nextPageToken: String?
}

/// A Firestore database instance within a project.
struct FirestoreDatabase: Decodable, Sendable, Identifiable, Equatable {
    let name: String        // projects/P/databases/D
    let type: String?       // FIRESTORE_NATIVE / DATASTORE_MODE
    let locationId: String?
    let concurrencyMode: String?

    var id: String { name }
    var databaseID: String {
        name.split(separator: "/").last.map(String.init) ?? "(default)"
    }
    var displayID: String {
        databaseID == "(default)" ? "(default)" : databaseID
    }
}

struct ListDatabasesResponse: Decodable, Sendable {
    let databases: [FirestoreDatabase]?
}
