import Foundation

/// Talks to Google's OAuth 2.0 endpoints for the Authorization Code Flow with
/// PKCE. Native iOS clients are public clients: there is **no client secret**.
///
/// Endpoints:
///  - Authorization: https://accounts.google.com/o/oauth2/v2/auth
///  - Token:         https://oauth2.googleapis.com/token
///  - Revoke:        https://oauth2.googleapis.com/revoke
///  - UserInfo:      https://openidconnect.googleapis.com/v1/userinfo
protocol OAuthClient: Sendable {
    func authorizationURL(challenge: PKCEChallenge, state: String, loginHint: String?) throws -> URL
    func exchange(code: String, verifier: String) async throws -> TokenResponse
    func refresh(refreshToken: String) async throws -> TokenResponse
    func revoke(token: String) async throws
    func fetchUserInfo(accessToken: String) async throws -> UserInfo
}

/// OpenID Connect userinfo payload (only the fields we display).
struct UserInfo: Decodable, Sendable {
    let sub: String
    let email: String?
    let name: String?
    let picture: String?
}

struct GoogleOAuthClient: OAuthClient {
    private let clientID: String
    private let redirectURI: String
    private let scopeString: String
    private let session: URLSession
    private let log = RedactedLog(category: "oauth")

    private let authEndpoint = URL(static: "https://accounts.google.com/o/oauth2/v2/auth")
    private let tokenEndpoint = URL(static: "https://oauth2.googleapis.com/token")
    private let revokeEndpoint = URL(static: "https://oauth2.googleapis.com/revoke")
    private let userInfoEndpoint = URL(static: "https://openidconnect.googleapis.com/v1/userinfo")

    init(
        clientID: String = AppConfig.oauthClientID,
        redirectURI: String = AppConfig.oauthRedirectURI,
        scopeString: String = AppConfig.oauthScopeString,
        session: URLSession = .shared
    ) {
        self.clientID = clientID
        self.redirectURI = redirectURI
        self.scopeString = scopeString
        self.session = session
    }

    // MARK: Authorization URL

    func authorizationURL(challenge: PKCEChallenge, state: String, loginHint: String?) throws -> URL {
        guard AppConfig.isOAuthConfigured else { throw AuthError.notConfigured }
        guard var components = URLComponents(url: authEndpoint, resolvingAgainstBaseURL: false) else {
            throw AuthError.invalidRequest
        }
        var items: [URLQueryItem] = [
            .init(name: "client_id", value: clientID),
            .init(name: "redirect_uri", value: redirectURI),
            .init(name: "response_type", value: "code"),
            .init(name: "scope", value: scopeString),
            .init(name: "code_challenge", value: challenge.challenge),
            .init(name: "code_challenge_method", value: challenge.method),
            .init(name: "state", value: state),
            .init(name: "access_type", value: "offline"),
            .init(name: "prompt", value: "consent"),
            .init(name: "include_granted_scopes", value: "true")
        ]
        if let loginHint { items.append(.init(name: "login_hint", value: loginHint)) }
        components.queryItems = items
        guard let url = components.url else { throw AuthError.invalidRequest }
        return url
    }

    // MARK: Token exchange / refresh

    func exchange(code: String, verifier: String) async throws -> TokenResponse {
        try await postToken(fields: [
            "client_id": clientID,
            "code": code,
            "code_verifier": verifier,
            "grant_type": "authorization_code",
            "redirect_uri": redirectURI
        ])
    }

    func refresh(refreshToken: String) async throws -> TokenResponse {
        try await postToken(fields: [
            "client_id": clientID,
            "refresh_token": refreshToken,
            "grant_type": "refresh_token"
        ])
    }

    private func postToken(fields: [String: String]) async throws -> TokenResponse {
        var request = URLRequest(url: tokenEndpoint)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = Self.formEncode(fields).data(using: .utf8)
        request.timeoutInterval = 30

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch let urlError as URLError {
            if urlError.code == .cancelled { throw APIError.cancelled }
            throw APIError.transport(underlying: urlError.code.rawValue.description)
        }
        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        log.http(method: "POST", url: tokenEndpoint, status: http.statusCode, note: "token")

        if (200...299).contains(http.statusCode) {
            do {
                return try JSONDecoder().decode(TokenResponse.self, from: data)
            } catch {
                throw APIError.decoding(context: "TokenResponse")
            }
        }

        // Parse the OAuth error payload ({ error, error_description }).
        let payload = try? JSONDecoder().decode(OAuthErrorPayload.self, from: data)
        let code = payload?.error ?? "invalid_request"
        if code == "invalid_grant" {
            throw AuthError.reauthenticationRequired
        }
        throw AuthError.tokenRequest(error: code, description: payload?.errorDescription)
    }

    // MARK: Revocation

    func revoke(token: String) async throws {
        var request = URLRequest(url: revokeEndpoint)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = Self.formEncode(["token": token]).data(using: .utf8)
        request.timeoutInterval = 20
        do {
            let (_, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
            log.http(method: "POST", url: revokeEndpoint, status: http.statusCode, note: "revoke")
            // Google returns 200 on success; already-invalid tokens may 400 —
            // treat that as effectively revoked.
            guard (200...299).contains(http.statusCode) || http.statusCode == 400 else {
                throw APIError.server(status: http.statusCode, google: nil)
            }
        } catch let urlError as URLError {
            throw APIError.transport(underlying: urlError.code.rawValue.description)
        }
    }

    // MARK: UserInfo

    func fetchUserInfo(accessToken: String) async throws -> UserInfo {
        var request = URLRequest(url: userInfoEndpoint)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 20
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        log.http(method: "GET", url: userInfoEndpoint, status: http.statusCode, note: "userinfo")
        guard (200...299).contains(http.statusCode) else {
            if http.statusCode == 401 { throw APIError.unauthorized }
            throw APIError.server(status: http.statusCode, google: nil)
        }
        do {
            return try JSONDecoder().decode(UserInfo.self, from: data)
        } catch {
            throw APIError.decoding(context: "UserInfo")
        }
    }

    // MARK: Helpers

    private static func formEncode(_ fields: [String: String]) -> String {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "+&=")
        return fields
            .map { key, value in
                let k = key.addingPercentEncoding(withAllowedCharacters: allowed) ?? key
                let v = value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
                return "\(k)=\(v)"
            }
            .joined(separator: "&")
    }
}

private struct OAuthErrorPayload: Decodable {
    let error: String?
    let errorDescription: String?
    enum CodingKeys: String, CodingKey {
        case error
        case errorDescription = "error_description"
    }
}
