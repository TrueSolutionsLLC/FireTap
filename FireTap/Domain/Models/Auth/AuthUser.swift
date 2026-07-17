import Foundation

/// A Firebase Authentication user account as returned by the Identity Toolkit
/// Admin API (`accounts:batchGet` / `accounts:lookup`).
///
/// Secret fields the API may return (password hash, salt) are deliberately
/// **not** decoded so they can never be displayed, logged, or copied.
struct AuthUser: Codable, Sendable, Identifiable, Hashable {
    let localId: String
    let email: String?
    let emailVerified: Bool?
    let displayName: String?
    let photoUrl: String?
    let phoneNumber: String?
    let disabled: Bool?
    let providerUserInfo: [ProviderInfo]?
    /// Custom claims, delivered as a JSON string.
    let customAttributes: String?
    let tenantId: String?

    // Timestamps arrive as strings in mixed units; keep raw + expose parsed.
    let createdAt: String?
    let lastLoginAt: String?
    let lastRefreshAt: String?
    let validSince: String?

    var id: String { localId }

    struct ProviderInfo: Codable, Sendable, Hashable, Identifiable {
        let providerId: String?
        let rawId: String?
        let email: String?
        let displayName: String?
        let photoUrl: String?
        let phoneNumber: String?

        var id: String { (providerId ?? "?") + "|" + (rawId ?? email ?? phoneNumber ?? "") }
    }

    enum CodingKeys: String, CodingKey {
        case localId, email, emailVerified, displayName, photoUrl, phoneNumber
        case disabled, providerUserInfo, customAttributes, tenantId
        case createdAt, lastLoginAt, lastRefreshAt, validSince
    }
}

extension AuthUser {
    var isDisabled: Bool { disabled ?? false }
    var isAnonymous: Bool { (providerUserInfo ?? []).isEmpty && (email == nil) && (phoneNumber == nil) }

    /// Best label to show for the account in a list.
    var primaryLabel: String {
        if let displayName, !displayName.isEmpty { return displayName }
        if let email, !email.isEmpty { return email }
        if let phoneNumber, !phoneNumber.isEmpty { return phoneNumber }
        return isAnonymous ? "Anonymous user" : localId
    }

    var providerLabels: [String] {
        (providerUserInfo ?? []).compactMap { $0.providerId }.map(Self.friendlyProvider)
    }

    static func friendlyProvider(_ id: String) -> String {
        switch id {
        case "password": return "Email/Password"
        case "phone": return "Phone"
        case "google.com": return "Google"
        case "apple.com": return "Apple"
        case "facebook.com": return "Facebook"
        case "github.com": return "GitHub"
        case "twitter.com": return "Twitter/X"
        case "microsoft.com": return "Microsoft"
        case "anonymous": return "Anonymous"
        default: return id
        }
    }

    var createdDate: Date? { Self.dateFromEpochMillis(createdAt) }
    var lastSignInDate: Date? { Self.dateFromEpochMillis(lastLoginAt) }
    var lastRefreshDate: Date? { Self.dateFromRFC3339(lastRefreshAt) }
    var validSinceDate: Date? { Self.dateFromEpochSeconds(validSince) }

    /// Custom claims parsed into a sorted key/value list for display. Returns an
    /// empty array when there are none or the payload can't be parsed.
    var customClaims: [(key: String, value: String)] {
        guard let customAttributes, !customAttributes.isEmpty,
              let data = customAttributes.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return [] }
        return object
            .map { (key: $0.key, value: String(describing: $0.value)) }
            .sorted { $0.key < $1.key }
    }

    private static func dateFromEpochMillis(_ raw: String?) -> Date? {
        guard let raw, let ms = Double(raw) else { return nil }
        return Date(timeIntervalSince1970: ms / 1000)
    }

    private static func dateFromEpochSeconds(_ raw: String?) -> Date? {
        guard let raw, let s = Double(raw) else { return nil }
        return Date(timeIntervalSince1970: s)
    }

    private static func dateFromRFC3339(_ raw: String?) -> Date? {
        guard let raw else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: raw) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: raw)
    }
}

// MARK: - API envelopes

struct DownloadAccountResponse: Codable, Sendable {
    let users: [AuthUser]?
    let nextPageToken: String?
}

struct LookupAccountResponse: Codable, Sendable {
    let users: [AuthUser]?
}

struct QueryAccountResponse: Codable, Sendable {
    /// Total number of accounts, returned as a string by the API.
    let recordsCount: String?
    var count: Int? { recordsCount.flatMap(Int.init) }
}
