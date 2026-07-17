import Foundation

/// A Google account the user has connected. Contains no secret material —
/// refresh tokens are stored separately alongside this record in the Keychain.
struct ConnectedAccount: Codable, Sendable, Identifiable, Hashable {
    /// Stable Google subject identifier (`sub`) from the ID token.
    let id: String
    var email: String
    var displayName: String?
    var avatarURL: URL?

    /// Initials for avatar fallback, e.g. "RJ".
    var initials: String {
        let name = displayName ?? ""
        let source = name.isEmpty ? email : name
        let parts = source.split(whereSeparator: { $0 == " " || $0 == "." || $0 == "@" })
        let letters = parts.prefix(2).compactMap { $0.first }
        let joined = String(letters).uppercased()
        return joined.isEmpty ? "?" : joined
    }
}
