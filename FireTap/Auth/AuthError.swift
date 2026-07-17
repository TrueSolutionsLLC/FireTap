import Foundation

/// Errors specific to the OAuth sign-in flow. Each maps to an honest UI state.
enum AuthError: Error, Sendable, Equatable {
    /// OAuth client id is not configured.
    case notConfigured
    /// The user dismissed the Google sign-in sheet.
    case userCanceled
    /// The `state` returned by Google did not match the one we sent (possible
    /// CSRF / interception) — the response is rejected.
    case stateMismatch
    /// The callback URL contained no authorization code.
    case missingAuthorizationCode
    /// Google returned an explicit error on the callback (e.g. access_denied).
    case authorizationDenied(String)
    /// The token exchange or refresh failed with an OAuth error payload.
    case tokenRequest(error: String, description: String?)
    /// The refresh token is no longer valid (revoked/expired) — reauth needed.
    case reauthenticationRequired
    /// The granted scopes don't cover what the app needs.
    case missingScopes(missing: [String])
    /// Could not build a valid authorization request URL.
    case invalidRequest
    /// Could not read required user identity from the token response.
    case missingIdentity

    var userMessage: String {
        switch self {
        case .notConfigured:
            return "Google sign-in isn't configured. Add your OAuth client id to Secrets.xcconfig."
        case .userCanceled:
            return "Sign-in was canceled."
        case .stateMismatch:
            return "Sign-in couldn't be verified and was stopped for your safety. Please try again."
        case .missingAuthorizationCode:
            return "Google didn't return an authorization code. Please try again."
        case .authorizationDenied(let reason):
            return "Google declined the sign-in: \(reason)."
        case .tokenRequest(let error, let description):
            return description ?? "Couldn't complete sign-in (\(error))."
        case .reauthenticationRequired:
            return "Your session is no longer valid. Please sign in again."
        case .missingScopes(let missing):
            return "Some required permissions weren't granted: \(missing.joined(separator: ", ")). Please sign in again and allow all requested access."
        case .invalidRequest:
            return "Couldn't start sign-in due to an internal configuration problem."
        case .missingIdentity:
            return "Couldn't read your account identity from Google's response."
        }
    }
}
