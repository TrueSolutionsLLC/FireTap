import Foundation

/// A value describing one HTTP request. Immutable and `Sendable`.
struct HTTPRequest: Sendable {
    enum Method: String, Sendable {
        case get = "GET"
        case post = "POST"
        case patch = "PATCH"
        case put = "PUT"
        case delete = "DELETE"
    }

    var method: Method
    var url: URL
    var query: [URLQueryItem]
    var headers: [String: String]
    var body: Data?
    var timeout: TimeInterval
    /// Status codes treated as success in addition to 2xx (e.g. 308 for GCS resumable uploads).
    var acceptableAdditionalStatuses: Set<Int>

    init(
        _ method: Method,
        url: URL,
        query: [URLQueryItem] = [],
        headers: [String: String] = [:],
        body: Data? = nil,
        timeout: TimeInterval = 30,
        acceptableAdditionalStatuses: Set<Int> = []
    ) {
        self.method = method
        self.url = url
        self.query = query
        self.headers = headers
        self.body = body
        self.timeout = timeout
        self.acceptableAdditionalStatuses = acceptableAdditionalStatuses
    }

    /// Fully resolved URL including query items.
    var resolvedURL: URL {
        guard !query.isEmpty,
              var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url
        }
        var items = components.queryItems ?? []
        items.append(contentsOf: query)
        components.queryItems = items
        return components.url ?? url
    }
}

/// The result of a successful HTTP exchange (2xx). Non-2xx maps to `APIError`.
struct HTTPResponse: Sendable {
    let data: Data
    let status: Int
    let etag: String?
    let location: String?
}

/// Formats a `Content-Range` header value for byte-range uploads.
enum HTTPContentRange {
    static func header(start: Int, end: Int, total: Int) -> String {
        "bytes \(start)-\(end)/\(total)"
    }
}
