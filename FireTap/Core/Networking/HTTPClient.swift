import Foundation

/// Transport that performs HTTP requests with typed error mapping, exponential
/// backoff + jitter for retryable failures, `Retry-After` support, timeouts and
/// cooperative cancellation. It is intentionally auth-agnostic: bearer tokens
/// are injected by the caller (`GoogleAPIClient`) so token-refresh coordination
/// lives in exactly one place.
protocol HTTPTransport: Sendable {
    func send(_ request: HTTPRequest, bearerToken: String?) async throws -> HTTPResponse
}

actor HTTPClient: HTTPTransport {
    private let session: URLSession
    private let backoff: Backoff
    private let log = RedactedLog(category: "http")

    init(session: URLSession = HTTPClient.makeSession(), backoff: Backoff = Backoff()) {
        self.session = session
        self.backoff = backoff
    }

    static func makeSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.waitsForConnectivity = false
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 120
        config.httpAdditionalHeaders = ["Accept": "application/json"]
        return URLSession(configuration: config)
    }

    func send(_ request: HTTPRequest, bearerToken: String?) async throws -> HTTPResponse {
        var attempt = 0
        while true {
            try Task.checkCancellation()

            let urlRequest = makeURLRequest(request, bearerToken: bearerToken)
            do {
                let (data, response) = try await session.data(for: urlRequest)
                guard let http = response as? HTTPURLResponse else {
                    throw APIError.invalidResponse
                }
                let etag = http.value(forHTTPHeaderField: "ETag")
                log.http(method: request.method.rawValue, url: request.resolvedURL, status: http.statusCode)

                switch http.statusCode {
                case 200...299:
                    return HTTPResponse(data: data, status: http.statusCode, etag: etag)

                case 401:
                    throw APIError.unauthorized

                case 403:
                    throw APIError.permissionDenied(message: Self.googleError(from: data)?.message)

                case 404:
                    throw APIError.notFound(message: Self.googleError(from: data)?.message)

                case 409, 412:
                    throw APIError.preconditionFailed(message: Self.googleError(from: data)?.message)

                case 429:
                    let retryAfter = Self.retryAfter(from: http)
                    if attempt < backoff.maxRetries {
                        try await sleep(backoff.delay(forAttempt: attempt, retryAfter: retryAfter))
                        attempt += 1
                        continue
                    }
                    throw APIError.rateLimited(retryAfter: retryAfter)

                case 500...599:
                    if attempt < backoff.maxRetries {
                        let retryAfter = Self.retryAfter(from: http)
                        try await sleep(backoff.delay(forAttempt: attempt, retryAfter: retryAfter))
                        attempt += 1
                        continue
                    }
                    throw APIError.server(status: http.statusCode, google: Self.googleError(from: data))

                default:
                    throw APIError.server(status: http.statusCode, google: Self.googleError(from: data))
                }
            } catch let error as APIError {
                throw error
            } catch let urlError as URLError {
                if urlError.code == .cancelled { throw APIError.cancelled }
                if attempt < backoff.maxRetries, Self.isRetryable(urlError) {
                    try await sleep(backoff.delay(forAttempt: attempt))
                    attempt += 1
                    continue
                }
                throw APIError.transport(underlying: urlError.code.rawValue.description)
            } catch is CancellationError {
                throw APIError.cancelled
            } catch {
                throw APIError.transport(underlying: "unknown")
            }
        }
    }

    // MARK: Helpers

    private func makeURLRequest(_ request: HTTPRequest, bearerToken: String?) -> URLRequest {
        var urlRequest = URLRequest(url: request.resolvedURL)
        urlRequest.httpMethod = request.method.rawValue
        urlRequest.timeoutInterval = request.timeout
        urlRequest.httpBody = request.body
        for (key, value) in request.headers {
            urlRequest.setValue(value, forHTTPHeaderField: key)
        }
        if let bearerToken {
            urlRequest.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
        }
        if request.body != nil, urlRequest.value(forHTTPHeaderField: "Content-Type") == nil {
            urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        return urlRequest
    }

    private func sleep(_ seconds: TimeInterval) async throws {
        try await Task.sleep(nanoseconds: UInt64(max(0, seconds) * 1_000_000_000))
    }

    private static func isRetryable(_ error: URLError) -> Bool {
        switch error.code {
        case .timedOut, .cannotConnectToHost, .networkConnectionLost,
             .dnsLookupFailed, .notConnectedToInternet, .cannotFindHost:
            return true
        default:
            return false
        }
    }

    private static func retryAfter(from response: HTTPURLResponse) -> TimeInterval? {
        guard let value = response.value(forHTTPHeaderField: "Retry-After") else { return nil }
        if let seconds = TimeInterval(value) { return seconds }
        // HTTP-date form.
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        if let date = formatter.date(from: value) {
            return max(0, date.timeIntervalSinceNow)
        }
        return nil
    }

    static func googleError(from data: Data) -> GoogleAPIError? {
        try? JSONDecoder().decode(GoogleAPIError.self, from: data)
    }
}
