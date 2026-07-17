import Foundation

/// Authorized JSON client for Google REST APIs. Attaches the active account's
/// bearer token, and on a 401 performs exactly one forced token refresh + retry
/// before surfacing `.unauthorized`. All refresh coordination happens inside
/// `TokenService`, so there are never duplicate refreshes.
struct GoogleAPIClient: Sendable {
    private let transport: HTTPTransport
    private let tokenProvider: TokenProviding
    private let decoder: JSONDecoder

    init(transport: HTTPTransport, tokenProvider: TokenProviding) {
        self.transport = transport
        self.tokenProvider = tokenProvider
        self.decoder = JSONDecoder()
    }

    // MARK: Decoded requests

    func get<T: Decodable & Sendable>(
        url: URL,
        query: [URLQueryItem] = [],
        headers: [String: String] = [:]
    ) async throws -> T {
        let response = try await sendRaw(HTTPRequest(.get, url: url, query: query, headers: headers))
        return try decode(T.self, from: response.data)
    }

    func send<T: Decodable & Sendable>(_ request: HTTPRequest) async throws -> T {
        let response = try await sendRaw(request)
        return try decode(T.self, from: response.data)
    }

    @discardableResult
    func sendVoid(_ request: HTTPRequest) async throws -> HTTPResponse {
        try await sendRaw(request)
    }

    /// Performs the request with auth, retrying once after a forced refresh on
    /// a 401. Returns the raw `HTTPResponse` (exposes ETag for callers that
    /// need preconditions).
    func sendRaw(_ request: HTTPRequest) async throws -> HTTPResponse {
        let token = try await tokenProvider.validAccessToken(forceRefresh: false)
        do {
            return try await transport.send(request, bearerToken: token)
        } catch APIError.unauthorized {
            let refreshed = try await tokenProvider.validAccessToken(forceRefresh: true)
            do {
                return try await transport.send(request, bearerToken: refreshed)
            } catch APIError.unauthorized {
                throw APIError.unauthorized
            }
        }
    }

    // MARK: Helpers

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        if data.isEmpty, let empty = EmptyResponse() as? T { return empty }
        do {
            return try decoder.decode(type, from: data)
        } catch {
            throw APIError.decoding(context: String(describing: type))
        }
    }

    static func jsonBody<T: Encodable>(_ value: T) throws -> Data {
        try JSONEncoder().encode(value)
    }
}

/// Placeholder for endpoints that return an empty 2xx body.
struct EmptyResponse: Decodable, Sendable { init() {} }
