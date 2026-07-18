import Foundation
import Observation

@MainActor
@Observable
final class ProjectsViewModel {
    enum SortOrder: String, CaseIterable, Identifiable {
        case activeThenName = "Active first"
        case name = "Name"
        case recent = "Recently opened"
        var id: String { rawValue }
    }

    private(set) var phase: AsyncPhase<[FirebaseProject]> = .idle
    var searchText: String = ""
    var sortOrder: SortOrder = .activeThenName

    private let projectsService: ProjectsService
    private let preferences: PreferencesStore
    private let accountID: String

    init(projectsService: ProjectsService, preferences: PreferencesStore, accountID: String) {
        self.projectsService = projectsService
        self.preferences = preferences
        self.accountID = accountID
    }

    var connectedCount: Int { phase.value?.count ?? 0 }

    var activeCount: Int {
        (phase.value ?? []).filter(\.isActive).count
    }

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
            // Keep showing previous results if we had any; still surface the error.
            if phase.value == nil {
                phase = .failed(error)
            } else {
                phase = .failed(error)
            }
        } catch {
            phase = .failed(.transport(underlying: "unknown"))
        }
    }

    /// Filtered + sorted projects for display.
    var displayedProjects: [FirebaseProject] {
        guard let all = phase.value else { return [] }
        let filtered = ProjectListOrdering.filter(all, searchText: searchText)
        let pinned = preferences.pinnedProjectIDs(account: accountID)
        switch sortOrder {
        case .activeThenName:
            return ProjectListOrdering.sort(filtered, pinnedIDs: pinned)
        case .name:
            return filtered.sorted {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
        case .recent:
            let last = preferences.lastOpenedProjectID(account: accountID)
            return ProjectListOrdering.sort(filtered, pinnedIDs: pinned, preferRecentID: last)
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
