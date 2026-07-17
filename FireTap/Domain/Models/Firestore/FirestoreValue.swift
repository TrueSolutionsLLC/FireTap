import Foundation

/// A Firestore field value in the REST wire format. Covers every Firestore
/// field type so documents round-trip losslessly.
indirect enum FirestoreValue: Sendable, Equatable {
    case null
    case boolean(Bool)
    case integer(Int64)
    case double(Double)
    case timestamp(Date)
    case string(String)
    case bytes(String)          // base64-encoded
    case reference(String)      // full document path
    case geoPoint(latitude: Double, longitude: Double)
    case array([FirestoreValue])
    case map([String: FirestoreValue])

    /// Short type name for UI.
    var typeName: String {
        switch self {
        case .null: return "null"
        case .boolean: return "bool"
        case .integer: return "int"
        case .double: return "double"
        case .timestamp: return "timestamp"
        case .string: return "string"
        case .bytes: return "bytes"
        case .reference: return "reference"
        case .geoPoint: return "geopoint"
        case .array: return "array"
        case .map: return "map"
        }
    }

    /// Compact, human-readable rendering for list rows.
    var displayString: String {
        switch self {
        case .null: return "null"
        case .boolean(let b): return b ? "true" : "false"
        case .integer(let i): return String(i)
        case .double(let d): return String(d)
        case .timestamp(let date): return ISO8601DateFormatter().string(from: date)
        case .string(let s): return s
        case .bytes: return "<bytes>"
        case .reference(let r): return r
        case .geoPoint(let lat, let lng): return "(\(lat), \(lng))"
        case .array(let values): return "[\(values.count)]"
        case .map(let fields): return "{\(fields.count)}"
        }
    }
}

// MARK: - Codable (REST wire format)

extension FirestoreValue: Codable {
    private enum CodingKeys: String, CodingKey {
        case nullValue, booleanValue, integerValue, doubleValue, timestampValue
        case stringValue, bytesValue, referenceValue, geoPointValue, arrayValue, mapValue
    }

    private struct GeoPoint: Codable { let latitude: Double?; let longitude: Double? }
    private struct ArrayWrapper: Codable { let values: [FirestoreValue]? }
    private struct MapWrapper: Codable { let fields: [String: FirestoreValue]? }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if container.contains(.nullValue) {
            self = .null
        } else if let b = try container.decodeIfPresent(Bool.self, forKey: .booleanValue) {
            self = .boolean(b)
        } else if let i = try container.decodeIfPresent(String.self, forKey: .integerValue) {
            self = .integer(Int64(i) ?? 0)
        } else if let d = try container.decodeIfPresent(Double.self, forKey: .doubleValue) {
            self = .double(d)
        } else if let ts = try container.decodeIfPresent(String.self, forKey: .timestampValue) {
            self = .timestamp(Self.date(from: ts))
        } else if let s = try container.decodeIfPresent(String.self, forKey: .stringValue) {
            self = .string(s)
        } else if let bytes = try container.decodeIfPresent(String.self, forKey: .bytesValue) {
            self = .bytes(bytes)
        } else if let ref = try container.decodeIfPresent(String.self, forKey: .referenceValue) {
            self = .reference(ref)
        } else if let geo = try container.decodeIfPresent(GeoPoint.self, forKey: .geoPointValue) {
            self = .geoPoint(latitude: geo.latitude ?? 0, longitude: geo.longitude ?? 0)
        } else if let array = try container.decodeIfPresent(ArrayWrapper.self, forKey: .arrayValue) {
            self = .array(array.values ?? [])
        } else if let map = try container.decodeIfPresent(MapWrapper.self, forKey: .mapValue) {
            self = .map(map.fields ?? [:])
        } else {
            self = .null
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .null:
            try container.encodeNil(forKey: .nullValue)
        case .boolean(let b):
            try container.encode(b, forKey: .booleanValue)
        case .integer(let i):
            try container.encode(String(i), forKey: .integerValue)
        case .double(let d):
            try container.encode(d, forKey: .doubleValue)
        case .timestamp(let date):
            try container.encode(Self.string(from: date), forKey: .timestampValue)
        case .string(let s):
            try container.encode(s, forKey: .stringValue)
        case .bytes(let b):
            try container.encode(b, forKey: .bytesValue)
        case .reference(let r):
            try container.encode(r, forKey: .referenceValue)
        case .geoPoint(let lat, let lng):
            try container.encode(GeoPoint(latitude: lat, longitude: lng), forKey: .geoPointValue)
        case .array(let values):
            try container.encode(ArrayWrapper(values: values), forKey: .arrayValue)
        case .map(let fields):
            try container.encode(MapWrapper(fields: fields), forKey: .mapValue)
        }
    }

    private static func date(from string: String) -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: string) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: string) ?? Date(timeIntervalSince1970: 0)
    }

    private static func string(from date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }
}
