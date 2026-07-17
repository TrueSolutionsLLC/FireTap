import Foundation
import OSLog

/// Central logger that is safe by construction: it never logs tokens,
/// authorization headers, request/response bodies, document contents, or user
/// emails. Callers pass structured, already-safe fields; anything that *might*
/// be sensitive is routed through `redact`.
struct RedactedLog: Sendable {
    private let logger: Logger

    init(category: String) {
        self.logger = Logger(subsystem: AppConfig.bundleID, category: category)
    }

    func debug(_ message: String) { logger.debug("\(message, privacy: .public)") }
    func info(_ message: String) { logger.info("\(message, privacy: .public)") }
    func notice(_ message: String) { logger.notice("\(message, privacy: .public)") }
    func warning(_ message: String) { logger.warning("\(message, privacy: .public)") }
    func error(_ message: String) { logger.error("\(message, privacy: .public)") }

    /// Logs an HTTP exchange with sensitive parts stripped: only method, a
    /// path with query values removed, and the status code are recorded.
    func http(method: String, url: URL, status: Int?, note: String? = nil) {
        let safePath = Self.redactURL(url)
        let statusText = status.map(String.init) ?? "-"
        let suffix = note.map { " (\($0))" } ?? ""
        logger.info("HTTP \(method, privacy: .public) \(safePath, privacy: .public) -> \(statusText, privacy: .public)\(suffix, privacy: .public)")
    }

    /// Removes query values and keeps only the host + path so no ids or
    /// tokens embedded in query strings leak into logs.
    static func redactURL(_ url: URL) -> String {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return "<url>"
        }
        if let items = components.queryItems, !items.isEmpty {
            components.queryItems = items.map { URLQueryItem(name: $0.name, value: "•") }
        }
        let host = components.host ?? ""
        let path = components.path
        let query = components.query.map { "?\($0)" } ?? ""
        return "\(host)\(path)\(query)"
    }

    /// Masks a secret string to a short, non-reversible marker for debugging
    /// ("present"/"absent" + length), never the value itself.
    static func redact(_ secret: String?) -> String {
        guard let secret, !secret.isEmpty else { return "absent" }
        return "present(len:\(secret.count))"
    }
}
