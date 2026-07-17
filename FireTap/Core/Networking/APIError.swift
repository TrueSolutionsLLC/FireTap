import Foundation

/// Structured error payload returned by Google APIs
/// (`{ "error": { "code", "message", "status", "errors": [...] } }`).
struct GoogleAPIError: Decodable, Sendable, Equatable {
    struct Detail: Decodable, Sendable, Equatable {
        let message: String?
        let domain: String?
        let reason: String?
    }
    let code: Int?
    let message: String?
    let status: String?
    let errors: [Detail]?

    private enum RootKeys: String, CodingKey { case error }
    init(from decoder: Decoder) throws {
        let root = try decoder.container(keyedBy: RootKeys.self)
        let nested = try root.nestedContainer(keyedBy: CodingKeys.self, forKey: .error)
        code = try nested.decodeIfPresent(Int.self, forKey: .code)
        message = try nested.decodeIfPresent(String.self, forKey: .message)
        status = try nested.decodeIfPresent(String.self, forKey: .status)
        errors = try nested.decodeIfPresent([Detail].self, forKey: .errors)
    }
    private enum CodingKeys: String, CodingKey { case code, message, status, errors }
}

/// Typed API error surfaced to the app. Every case maps to an honest,
/// user-actionable state — there are no silent failures.
enum APIError: Error, Sendable, Equatable {
    /// OAuth is not configured (no client id).
    case notConfigured
    /// No connected account / no valid session.
    case notAuthenticated
    /// 401 — token invalid or expired even after refresh; reauth required.
    case unauthorized
    /// 403 — the account lacks permission or the API is not enabled.
    case permissionDenied(message: String?)
    /// 404 — resource not found.
    case notFound(message: String?)
    /// 409 / 412 — precondition failed (concurrent edit / ETag mismatch).
    case preconditionFailed(message: String?)
    /// 429 — rate limited; includes server-provided retry delay if any.
    case rateLimited(retryAfter: TimeInterval?)
    /// 5xx or otherwise unexpected server response.
    case server(status: Int, google: GoogleAPIError?)
    /// Network transport failure (offline, DNS, TLS...).
    case transport(underlying: String)
    /// Response could not be decoded into the expected type.
    case decoding(context: String)
    /// The request was cancelled.
    case cancelled
    /// A response arrived that wasn't an HTTP response, or was malformed.
    case invalidResponse

    /// A short, human-readable summary suitable for UI. Never contains
    /// tokens or payloads.
    var userMessage: String {
        switch self {
        case .notConfigured:
            return "Google sign-in isn't configured yet."
        case .notAuthenticated:
            return "You're not signed in."
        case .unauthorized:
            return "Your session expired. Please sign in again."
        case .permissionDenied(let message):
            return message ?? "Your account doesn't have permission for this, or the required API isn't enabled."
        case .notFound(let message):
            return message ?? "That resource couldn't be found."
        case .preconditionFailed:
            return "This changed on the server since you loaded it. Reload and try again."
        case .rateLimited:
            return "Google is rate-limiting requests. Try again shortly."
        case .server(let status, let google):
            return google?.message ?? "The server returned an error (\(status))."
        case .transport:
            return "Couldn't reach Google. Check your connection and try again."
        case .decoding:
            return "The response wasn't in the expected format."
        case .cancelled:
            return "The request was cancelled."
        case .invalidResponse:
            return "The server sent an unexpected response."
        }
    }

    /// Whether retrying the exact same request could plausibly succeed.
    var isRetryable: Bool {
        switch self {
        case .rateLimited, .transport, .server:
            return true
        default:
            return false
        }
    }
}
