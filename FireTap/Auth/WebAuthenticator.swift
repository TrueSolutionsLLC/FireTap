import Foundation
import UIKit
import AuthenticationServices

/// Thin async wrapper around `ASWebAuthenticationSession`. Runs on the main
/// actor because it presents system UI and needs a presentation anchor.
///
/// The system browser is used (not an in-app web view), so the user's Google
/// password is entered into Safari's secure context and never touches this app.
@MainActor
final class WebAuthenticator: NSObject {

    /// Starts the authentication session and returns the callback URL, or
    /// throws `AuthError.userCanceled` if dismissed.
    func authenticate(url: URL, callbackScheme: String) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: callbackScheme
            ) { callbackURL, error in
                if let error {
                    let nsError = error as NSError
                    if nsError.domain == ASWebAuthenticationSessionError.errorDomain,
                       nsError.code == ASWebAuthenticationSessionError.canceledLogin.rawValue {
                        continuation.resume(throwing: AuthError.userCanceled)
                    } else {
                        continuation.resume(throwing: AuthError.tokenRequest(
                            error: "session_error",
                            description: nsError.localizedDescription
                        ))
                    }
                    return
                }
                guard let callbackURL else {
                    continuation.resume(throwing: AuthError.missingAuthorizationCode)
                    return
                }
                continuation.resume(returning: callbackURL)
            }
            session.presentationContextProvider = self
            // Force a fresh browser session so account selection is always shown
            // and no residual cookie silently reuses a prior identity.
            session.prefersEphemeralWebBrowserSession = true
            if !session.start() {
                continuation.resume(throwing: AuthError.invalidRequest)
            }
        }
    }
}

extension WebAuthenticator: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        let window = scene?.keyWindow ?? scene?.windows.first
        return window ?? ASPresentationAnchor()
    }
}

/// Parses and validates the OAuth callback URL.
enum OAuthCallback {
    /// Returns the authorization code after validating `state`. Throws if the
    /// state does not match (CSRF protection) or an error is present.
    static func authorizationCode(from url: URL, expectedState: String) throws -> String {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw AuthError.missingAuthorizationCode
        }
        let items = components.queryItems ?? []
        func value(_ name: String) -> String? {
            items.first { $0.name == name }?.value
        }

        if let error = value("error") {
            throw AuthError.authorizationDenied(error)
        }
        guard let returnedState = value("state"), !returnedState.isEmpty else {
            throw AuthError.stateMismatch
        }
        guard constantTimeEquals(returnedState, expectedState) else {
            throw AuthError.stateMismatch
        }
        guard let code = value("code"), !code.isEmpty else {
            throw AuthError.missingAuthorizationCode
        }
        return code
    }

    /// Constant-time string comparison to avoid leaking length/timing info.
    static func constantTimeEquals(_ lhs: String, _ rhs: String) -> Bool {
        let a = Array(lhs.utf8)
        let b = Array(rhs.utf8)
        guard a.count == b.count else { return false }
        var difference: UInt8 = 0
        for i in 0..<a.count { difference |= a[i] ^ b[i] }
        return difference == 0
    }
}

private extension UIWindowScene {
    var keyWindow: UIWindow? { windows.first { $0.isKeyWindow } }
}
