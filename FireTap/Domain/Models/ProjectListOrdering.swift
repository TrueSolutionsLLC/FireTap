import Foundation

/// Pure ordering helpers for the project list — unit-tested without UI.
enum ProjectListOrdering {
    /// Active projects first, then alphabetical by display name (case-insensitive).
    /// Pinned projects float above non-pinned within the same active/inactive band.
    static func sort(
        _ projects: [FirebaseProject],
        pinnedIDs: Set<String> = [],
        preferRecentID: String? = nil
    ) -> [FirebaseProject] {
        projects.sorted { lhs, rhs in
            let lPinned = pinnedIDs.contains(lhs.projectId)
            let rPinned = pinnedIDs.contains(rhs.projectId)
            if lPinned != rPinned { return lPinned }

            if let preferRecentID {
                if lhs.projectId == preferRecentID { return true }
                if rhs.projectId == preferRecentID { return false }
            }

            if lhs.isActive != rhs.isActive { return lhs.isActive && !rhs.isActive }

            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    static func filter(_ projects: [FirebaseProject], searchText: String) -> [FirebaseProject] {
        let needle = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !needle.isEmpty else { return projects }
        return projects.filter {
            $0.name.lowercased().contains(needle)
                || $0.projectId.lowercased().contains(needle)
                || ($0.projectNumber?.lowercased().contains(needle) ?? false)
        }
    }
}
