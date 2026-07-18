import Foundation

/// Cloud Logging `entries.list` for a project.
protocol LoggingService: Sendable {
    func listEntries(
        projectID: String,
        filter: String?,
        pageSize: Int,
        pageToken: String?
    ) async throws -> ListLogEntriesResponse
}

struct LiveLoggingService: LoggingService {
    private let api: GoogleAPIClient
    private let base = URL(static: "https://logging.googleapis.com/v2")

    init(api: GoogleAPIClient) {
        self.api = api
    }

    func listEntries(
        projectID: String,
        filter: String?,
        pageSize: Int,
        pageToken: String?
    ) async throws -> ListLogEntriesResponse {
        let url = base.appendingPathComponent("entries:list")
        let body = try GoogleAPIClient.jsonBody(
            ListLogEntriesRequest(
                resourceNames: ["projects/\(projectID)"],
                filter: filter,
                orderBy: "timestamp desc",
                pageSize: pageSize,
                pageToken: pageToken
            )
        )
        return try await api.send(HTTPRequest(.post, url: url, body: body))
    }
}

// MARK: - Filter builders (pure)

enum LoggingFilter {
    /// Builds a Cloud Logging filter expression from optional severity,
    /// Cloud Function resource name, and time bounds. Empty inputs are omitted.
    static func build(
        severityAtLeast: String? = nil,
        functionResourceName: String? = nil,
        startTime: Date? = nil,
        endTime: Date? = nil
    ) -> String {
        var parts: [String] = []
        if let severityAtLeast, !severityAtLeast.isEmpty {
            parts.append("severity>=\(severityAtLeast)")
        }
        if let functionResourceName, !functionResourceName.isEmpty {
            let escaped = escapeFilterString(functionResourceName)
            parts.append("resource.type=\"cloud_function\"")
            parts.append("resource.labels.function_name=\"\(escaped)\"")
        }
        if let startTime {
            parts.append("timestamp>=\"\(iso8601(startTime))\"")
        }
        if let endTime {
            parts.append("timestamp<=\"\(iso8601(endTime))\"")
        }
        return parts.joined(separator: " AND ")
    }

    /// Escapes a value for use inside a double-quoted Logging filter string.
    static func escapeFilterString(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }

    private static func iso8601(_ date: Date) -> String {
        ISO8601DateFormatter().string(from: date)
    }
}

// MARK: - Models

struct LogEntry: Sendable, Identifiable, Equatable {
    let timestamp: String?
    let severity: String?
    let resource: LogResource?
    let textPayload: String?
    /// Raw JSON object bytes when the entry carries `jsonPayload`; otherwise nil.
    let jsonPayload: Data?
    let insertId: String?
    let trace: String?

    var id: String {
        if let insertId, !insertId.isEmpty { return insertId }
        return [timestamp, severity, textPayload].compactMap { $0 }.joined(separator: "|")
    }
}

struct LogResource: Codable, Sendable, Equatable {
    let type: String?
    let labels: [String: String]?
}

struct ListLogEntriesResponse: Sendable, Equatable {
    let entries: [LogEntry]
    let nextPageToken: String?
}

// MARK: - Request / decode

private struct ListLogEntriesRequest: Encodable {
    let resourceNames: [String]
    let filter: String?
    let orderBy: String?
    let pageSize: Int
    let pageToken: String?
}

extension ListLogEntriesResponse: Decodable {
    private enum CodingKeys: String, CodingKey {
        case entries, nextPageToken
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        entries = try container.decodeIfPresent([LogEntry].self, forKey: .entries) ?? []
        nextPageToken = try container.decodeIfPresent(String.self, forKey: .nextPageToken)
    }
}

extension LogEntry: Decodable {
    private enum CodingKeys: String, CodingKey {
        case timestamp, severity, resource, textPayload, jsonPayload, insertId, trace
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        timestamp = try container.decodeIfPresent(String.self, forKey: .timestamp)
        severity = try container.decodeIfPresent(String.self, forKey: .severity)
        resource = try container.decodeIfPresent(LogResource.self, forKey: .resource)
        textPayload = try container.decodeIfPresent(String.self, forKey: .textPayload)
        insertId = try container.decodeIfPresent(String.self, forKey: .insertId)
        trace = try container.decodeIfPresent(String.self, forKey: .trace)

        if container.contains(.jsonPayload),
           try container.decodeNil(forKey: .jsonPayload) == false {
            let value = try container.decode(JSONValue.self, forKey: .jsonPayload)
            jsonPayload = try JSONEncoder().encode(value)
        } else {
            jsonPayload = nil
        }
    }
}

/// Minimal JSON tree used only to re-encode `jsonPayload` into `Data`.
private enum JSONValue: Codable, Sendable {
    case null
    case bool(Bool)
    case number(Double)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else if let value = try? container.decode([String: JSONValue].self) {
            self = .object(value)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported JSON value")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null: try container.encodeNil()
        case .bool(let value): try container.encode(value)
        case .number(let value): try container.encode(value)
        case .string(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .object(let value): try container.encode(value)
        }
    }
}
