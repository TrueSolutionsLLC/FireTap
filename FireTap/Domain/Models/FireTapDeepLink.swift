import Foundation

/// Parsed deep link target: `firetap://project/{projectId}/module/{moduleRawValue}`.
struct FireTapDeepLink: Equatable, Sendable {
    let projectID: String
    let moduleRawValue: String?
}

enum FireTapDeepLinkParser {
    /// Parses `firetap://project/{projectId}/module/{moduleRawValue}` (path or host forms).
    static func parse(_ url: URL) -> FireTapDeepLink? {
        guard url.scheme?.lowercased() == "firetap" else { return nil }

        var segments: [String] = []
        if let host = url.host, !host.isEmpty {
            segments.append(host)
        }
        segments.append(contentsOf: url.path.split(separator: "/").map(String.init))

        guard segments.first == "project", segments.count >= 2 else { return nil }

        let projectID = segments[1]
        guard !projectID.isEmpty else { return nil }

        var moduleRawValue: String?
        if segments.count >= 4, segments[2] == "module" {
            moduleRawValue = segments[3]
        }

        return FireTapDeepLink(projectID: projectID, moduleRawValue: moduleRawValue)
    }
}
