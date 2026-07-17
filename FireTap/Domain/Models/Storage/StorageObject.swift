import Foundation

/// A Cloud Storage bucket (Cloud Storage JSON API `b.list`).
struct StorageBucket: Codable, Sendable, Identifiable, Hashable {
    let id: String?
    let name: String
    let location: String?
    let storageClass: String?
    let timeCreated: String?

    var identifier: String { name }
}

struct ListBucketsResponse: Codable, Sendable {
    let items: [StorageBucket]?
    let nextPageToken: String?
}

/// A single object within a bucket (Cloud Storage JSON API `objects.list`).
struct StorageObject: Codable, Sendable, Identifiable, Hashable {
    let name: String
    let bucket: String?
    let contentType: String?
    /// Object size in bytes, delivered as a string.
    let size: String?
    let updated: String?
    let timeCreated: String?
    let mediaLink: String?

    var id: String { name }

    var byteCount: Int64? { size.flatMap(Int64.init) }

    /// The last path component (file name) relative to a folder prefix.
    func displayName(strippingPrefix prefix: String) -> String {
        let trimmed = name.hasPrefix(prefix) ? String(name.dropFirst(prefix.count)) : name
        return trimmed.isEmpty ? name : trimmed
    }

    var updatedDate: Date? {
        guard let updated else { return nil }
        return ISO8601DateFormatter().date(from: updated)
    }
}

/// One page of objects. `prefixes` are pseudo-folders when a delimiter is used.
struct ListObjectsResponse: Codable, Sendable {
    let items: [StorageObject]?
    let prefixes: [String]?
    let nextPageToken: String?
}

enum StorageFormat {
    /// Human-readable byte size, or "—" when unknown.
    static func size(_ bytes: Int64?) -> String {
        guard let bytes else { return "—" }
        return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}
