import Foundation

/// Single source of truth for the app's identity and external configuration.
///
/// Every value here is sourced from `Config/*.xcconfig` (via `Info.plist`
/// build-setting substitution) so the product name, bundle id, OAuth client,
/// and StoreKit product id can be changed in one place without editing Swift.
///
/// Nothing in this type is a secret at rest: the OAuth *client id* for a native
/// iOS app is a public identifier, and the flow uses PKCE (no client secret).
enum AppConfig {

    // MARK: Info.plist access

    private static func string(_ key: String) -> String {
        (Bundle.main.object(forInfoDictionaryKey: key) as? String) ?? ""
    }

    // MARK: Product identity

    /// Human-facing product name, e.g. "FireTap".
    static var displayName: String {
        let value = string("PCAppDisplayName")
        return value.isEmpty ? "FireTap" : value
    }

    /// The app's bundle identifier.
    static var bundleID: String {
        Bundle.main.bundleIdentifier ?? string("CFBundleIdentifier")
    }

    /// Short marketing version, e.g. "1.0".
    static var marketingVersion: String {
        string("CFBundleShortVersionString")
    }

    /// Build number, e.g. "1".
    static var buildNumber: String {
        string("CFBundleVersion")
    }

    /// "debug" or "release".
    static var buildChannel: String {
        let value = string("PCBuildChannel")
        return value.isEmpty ? "release" : value
    }

    // MARK: OAuth

    /// Full Google OAuth client id (public identifier for a native app).
    static var oauthClientID: String {
        string("PCOAuthClientID").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Reversed-client-id custom URL scheme used as the redirect target.
    static var oauthRedirectScheme: String {
        string("PCOAuthRedirectScheme").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Full redirect URI registered with Google for the installed-app flow.
    static var oauthRedirectURI: String {
        "\(oauthRedirectScheme):/oauth2redirect"
    }

    /// True only when a real OAuth client id has been provided. When false the
    /// UI shows an honest "OAuth not configured" state instead of a broken
    /// sign-in button.
    static var isOAuthConfigured: Bool {
        !oauthClientID.isEmpty
            && !oauthClientID.hasPrefix("REPLACE_WITH_")
            && oauthClientID.hasSuffix(".apps.googleusercontent.com")
            && !oauthRedirectScheme.isEmpty
    }

    /// Minimum set of Google OAuth scopes the app requests, each paired with a
    /// plain-language explanation shown to the user *before* authorization.
    static let oauthScopes: [OAuthScope] = [
        OAuthScope(
            value: "openid",
            title: "Confirm your identity",
            explanation: "Used to sign you in securely. No password is ever seen by this app."
        ),
        OAuthScope(
            value: "https://www.googleapis.com/auth/userinfo.email",
            title: "See your email address",
            explanation: "Shown so you can tell which Google account is connected."
        ),
        OAuthScope(
            value: "https://www.googleapis.com/auth/userinfo.profile",
            title: "See your basic profile",
            explanation: "Your name and avatar are displayed in the account switcher."
        ),
        OAuthScope(
            value: "https://www.googleapis.com/auth/cloud-platform",
            title: "Manage your Google Cloud / Firebase projects",
            explanation: "Lets the app read your real projects, metrics, logs, Firestore data, users, storage and (with Pro + Safe Mode unlocked) perform the specific admin actions you approve. Requests go directly from your device to Google."
        ),
        OAuthScope(
            value: "https://www.googleapis.com/auth/firebase.database",
            title: "Access Realtime Database",
            explanation: "Only used when you open the Realtime Database module for a project."
        )
    ]

    /// Space-delimited scope string for the authorization request.
    static var oauthScopeString: String {
        oauthScopes.map(\.value).joined(separator: " ")
    }

    /// Scopes that must be granted for core functionality. If these are
    /// missing after sign-in the app asks the user to reauthenticate rather
    /// than silently failing later.
    static let requiredScopeValues: [String] = [
        "https://www.googleapis.com/auth/cloud-platform"
    ]

    // MARK: StoreKit

    /// Non-consumable lifetime Pro product id.
    static var storeKitProProductID: String {
        let value = string("PCStoreKitProProductID")
        return value.isEmpty ? "com.truesolutions.firetap.lifetime" : value
    }

    // MARK: Legal / support URLs

    static var supportURL: URL? { URL(string: string("PCSupportURL")) }
    static var privacyPolicyURL: URL? { URL(string: string("PCPrivacyPolicyURL")) }
    static var termsURL: URL? { URL(string: string("PCTermsURL")) }
}

/// A single OAuth scope plus a human-readable explanation of why it is needed.
struct OAuthScope: Identifiable, Hashable, Sendable {
    let value: String
    let title: String
    let explanation: String
    var id: String { value }
}
