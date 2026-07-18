import Foundation
import Observation

/// Stores non-sensitive, per-account project preferences (pins, favorites,
/// environment labels, last-opened project). Never stores credentials.
///
/// Values are namespaced by account id so switching accounts shows the right
/// pins and labels.
@MainActor
@Observable
final class PreferencesStore {
    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    // MARK: Pinned projects

    func pinnedProjectIDs(account: String) -> Set<String> {
        Set(array(forKey: key("pinned", account)))
    }

    func setPinned(_ pinned: Bool, projectID: String, account: String) {
        var current = pinnedProjectIDs(account: account)
        if pinned { current.insert(projectID) } else { current.remove(projectID) }
        defaults.set(Array(current), forKey: key("pinned", account))
    }

    func isPinned(_ projectID: String, account: String) -> Bool {
        pinnedProjectIDs(account: account).contains(projectID)
    }

    // MARK: Environment labels

    func environment(for projectID: String, account: String) -> ProjectEnvironment {
        let map = dictionary(forKey: key("labels", account))
        return map[projectID].flatMap(ProjectEnvironment.init(rawValue:)) ?? inferEnvironment(projectID)
    }

    func setEnvironment(_ environment: ProjectEnvironment, for projectID: String, account: String) {
        var map = dictionary(forKey: key("labels", account))
        map[projectID] = environment.rawValue
        defaults.set(map, forKey: key("labels", account))
    }

    /// Heuristic first guess from the project id (user can always override).
    /// This is a *label suggestion*, never treated as ground truth for safety.
    private func inferEnvironment(_ projectID: String) -> ProjectEnvironment {
        let lower = projectID.lowercased()
        if lower.contains("prod") { return .production }
        if lower.contains("stag") { return .staging }
        if lower.contains("dev") { return .development }
        if lower.contains("test") || lower.contains("sandbox") { return .test }
        return .unlabeled
    }

    // MARK: Favorites (resource keys)

    func favoriteResourceKeys(account: String) -> Set<String> {
        Set(array(forKey: key("favorites", account)))
    }

    func setFavorite(_ isFavorite: Bool, resourceKey: String, account: String) {
        var current = favoriteResourceKeys(account: account)
        if isFavorite {
            current.insert(resourceKey)
        } else {
            current.remove(resourceKey)
        }
        defaults.set(Array(current).sorted(), forKey: key("favorites", account))
    }

    func isFavorite(_ resourceKey: String, account: String) -> Bool {
        favoriteResourceKeys(account: account).contains(resourceKey)
    }

    // MARK: Recently viewed (resource keys, capped at 20)

    private static let recentlyViewedLimit = 20

    func recentlyViewedResourceKeys(account: String) -> [String] {
        array(forKey: key("recent", account))
    }

    func recordRecentlyViewed(_ resourceKey: String, account: String) {
        var current = recentlyViewedResourceKeys(account: account)
        current.removeAll { $0 == resourceKey }
        current.insert(resourceKey, at: 0)
        if current.count > Self.recentlyViewedLimit {
            current = Array(current.prefix(Self.recentlyViewedLimit))
        }
        defaults.set(current, forKey: key("recent", account))
    }

    func clearRecentlyViewed(account: String) {
        defaults.removeObject(forKey: key("recent", account))
    }

    // MARK: Last opened project

    func lastOpenedProjectID(account: String) -> String? {
        defaults.string(forKey: key("lastProject", account))
    }

    func setLastOpenedProjectID(_ id: String?, account: String) {
        if let id {
            defaults.set(id, forKey: key("lastProject", account))
        } else {
            defaults.removeObject(forKey: key("lastProject", account))
        }
    }

    // MARK: Helpers

    private func key(_ name: String, _ account: String) -> String {
        "pc.pref.\(name).\(account)"
    }

    private func array(forKey key: String) -> [String] {
        defaults.array(forKey: key) as? [String] ?? []
    }

    private func dictionary(forKey key: String) -> [String: String] {
        defaults.dictionary(forKey: key) as? [String: String] ?? [:]
    }
}
