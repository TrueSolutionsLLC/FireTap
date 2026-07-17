import Foundation
import Observation

@MainActor
@Observable
final class ProjectsViewModel {
    enum SortOrder: String, CaseIterable, Identifiable {
        case name = "Name"
        case recent = "Recently opened"
        var id: String { rawValue }
    }

    private(set) var phase: AsyncPhase<[FirebaseProject]> = .idle
    var searchText: String = ""
    var sortOrder: SortOrder = .name

    private let projectsService: ProjectsService
    private let preferences: PreferencesStore
    private let accountID: String

    init(projectsService: ProjectsService, preferences: PreferencesStore, accountID: String) {
        self.projectsService = projectsService
        self.preferences = preferences
        self.accountID = accountID
    }

    var connectedCount: Int { phase.value?.count ?? 0 }

    var productionCount: Int {
        (phase.value ?? []).filter {
            preferences.environment(for: $0.projectId, account: accountID).isProduction
        }.count
    }

    func load() async {
        if phase.value == nil { phase = .loading }
        do {
            let projects = try await projectsService.listProjects()
            phase = .loaded(projects)
        } catch let error as APIError {
            phase = .failed(error)
        } catch {
            phase = .failed(.transport(underlying: "unknown"))
        }
    }

    func refresh() async {
        do {
            let projects = try await projectsService.listProjects()
            phase = .loaded(projects)
        } catch let error as APIError {
            phase = .failed(error)
        } catch {
            phase = .failed(.transport(underlying: "unknown"))
        }
    }

    /// Filtered + sorted projects for display. Pinned always float to the top.
    var displayedProjects: [FirebaseProject] {
        guard let all = phase.value else { return [] }
        let filtered: [FirebaseProject]
        if searchText.trimmingCharacters(in: .whitespaces).isEmpty {
            filtered = all
        } else {
            let needle = searchText.lowercased()
            filtered = all.filter {
                $0.name.lowercased().contains(needle) || $0.projectId.lowercased().contains(needle)
            }
        }
        let pinned = preferences.pinnedProjectIDs(account: accountID)
        return filtered.sorted { lhs, rhs in
            let lPinned = pinned.contains(lhs.projectId)
            let rPinned = pinned.contains(rhs.projectId)
            if lPinned != rPinned { return lPinned }
            switch sortOrder {
            case .name:
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            case .recent:
                let last = preferences.lastOpenedProjectID(account: accountID)
                if lhs.projectId == last { return true }
                if rhs.projectId == last { return false }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
        }
    }

    func isPinned(_ project: FirebaseProject) -> Bool {
        preferences.isPinned(project.projectId, account: accountID)
    }

    func togglePin(_ project: FirebaseProject) {
        preferences.setPinned(!isPinned(project), projectID: project.projectId, account: accountID)
    }

    func environment(for project: FirebaseProject) -> ProjectEnvironment {
        preferences.environment(for: project.projectId, account: accountID)
    }

    func setEnvironment(_ environment: ProjectEnvironment, for project: FirebaseProject) {
        preferences.setEnvironment(environment, for: project.projectId, account: accountID)
    }
}
