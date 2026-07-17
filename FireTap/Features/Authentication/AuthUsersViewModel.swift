import Foundation
import Observation

@MainActor
@Observable
final class AuthUsersViewModel {
    enum Filter: String, CaseIterable, Identifiable {
        case all, verified, disabled, anonymous
        var id: String { rawValue }
        var title: String {
            switch self {
            case .all: return "All"
            case .verified: return "Verified"
            case .disabled: return "Disabled"
            case .anonymous: return "Anonymous"
            }
        }
    }

    let projectID: String

    var pageSize: Int = 50
    var filter: Filter = .all
    var searchText: String = ""

    private(set) var users: [AuthUser] = []
    private(set) var isLoading = false
    private(set) var isSearching = false
    private(set) var error: APIError?
    private(set) var nextPageToken: String?
    private(set) var hasLoadedOnce = false
    private(set) var totalCount: Int?
    /// A single account found via server-side lookup (email/phone/uid search).
    private(set) var searchMatch: AuthUser?
    private(set) var searchMissed = false

    private let service: AuthService

    init(projectID: String, service: AuthService) {
        self.projectID = projectID
        self.service = service
    }

    var reachedEnd: Bool { hasLoadedOnce && nextPageToken == nil }

    /// Client-side filtered view of the pages loaded so far.
    var displayedUsers: [AuthUser] {
        users.filter { user in
            switch filter {
            case .all: return true
            case .verified: return user.emailVerified == true
            case .disabled: return user.isDisabled
            case .anonymous: return user.isAnonymous
            }
        }
    }

    func loadFirstPage() async {
        users = []
        nextPageToken = nil
        hasLoadedOnce = false
        await loadCount()
        await loadPage(isFirst: true)
    }

    func loadNextPage() async {
        guard !isLoading, !reachedEnd else { return }
        await loadPage(isFirst: false)
    }

    private func loadCount() async {
        totalCount = try? await service.countUsers(projectID: projectID)
    }

    private func loadPage(isFirst: Bool) async {
        isLoading = true
        error = nil
        do {
            let response = try await service.listUsers(
                projectID: projectID,
                pageSize: pageSize,
                pageToken: isFirst ? nil : nextPageToken
            )
            users.append(contentsOf: response.users ?? [])
            // batchGet echoes the same token at the end of the list; treat an
            // empty page or an unchanged token as the end.
            let token = response.nextPageToken
            nextPageToken = (response.users?.isEmpty ?? true) ? nil : token
            hasLoadedOnce = true
        } catch let apiError as APIError {
            error = apiError
        } catch {
            self.error = .transport(underlying: "unknown")
        }
        isLoading = false
    }

    // MARK: Search

    func runSearch() async {
        let raw = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { clearSearch(); return }
        isSearching = true
        searchMatch = nil
        searchMissed = false
        error = nil
        do {
            let match = try await service.lookupUser(projectID: projectID, key: Self.classify(raw))
            searchMatch = match
            searchMissed = (match == nil)
        } catch let apiError as APIError {
            error = apiError
        } catch {
            self.error = .transport(underlying: "unknown")
        }
        isSearching = false
    }

    func clearSearch() {
        searchText = ""
        searchMatch = nil
        searchMissed = false
        isSearching = false
    }

    /// Chooses a lookup key from free text: an "@" implies email, a leading "+"
    /// (or all digits) implies phone, otherwise treat it as a UID.
    nonisolated static func classify(_ text: String) -> AuthLookupKey {
        if text.contains("@") { return .email(text) }
        let digits = text.filter { $0.isNumber || $0 == "+" }
        if text.hasPrefix("+") || (digits.count == text.count && !text.isEmpty) {
            return .phone(text.hasPrefix("+") ? text : "+" + text)
        }
        return .uid(text)
    }
}
