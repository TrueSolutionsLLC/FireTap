import SwiftUI

/// Account's real Firebase projects with search, sort, pin, and environment
/// labels. Selecting a project enters the console.
struct ProjectPickerView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var model: ProjectsViewModel?
    @State private var showingAccountSheet = false
    @State private var boundAccountID: String?
    @State private var showProGate = false

    var body: some View {
        NavigationStack {
            Group {
                if env.isRestoringProject {
                    LoadingStateView().padding()
                } else if let model {
                    content(model)
                } else {
                    LoadingStateView().padding()
                }
            }
            .appBackground()
            .navigationTitle("Projects")
            .toolbar { toolbar }
            .sheet(isPresented: $showingAccountSheet) {
                AccountSwitcherSheet()
            }
            .alert("FireTap Pro required", isPresented: $showProGate) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Free mode includes read-only access to one connected project. Unlock Pro for unlimited projects and write/admin actions.")
            }
        }
        .task(id: env.accountManager.activeAccountID) {
            await bindModelIfNeeded()
        }
    }

    private func bindModelIfNeeded() async {
        guard let account = env.accountManager.activeAccount else {
            model = nil
            boundAccountID = nil
            return
        }
        if boundAccountID != account.id {
            let vm = ProjectsViewModel(
                projectsService: env.projectsService,
                preferences: env.preferences,
                accountID: account.id
            )
            model = vm
            boundAccountID = account.id
            await vm.load()
        } else if model?.phase.value == nil, model?.phase.error == nil {
            await model?.load()
        }
    }

    @ViewBuilder
    private func content(_ model: ProjectsViewModel) -> some View {
        @Bindable var model = model
        switch model.phase {
        case .idle, .loading:
            LoadingStateView().padding()
        case .failed(let error):
            ErrorStateView(error: error) {
                Task { await model.load() }
            } reauth: {
                Task { await env.accountManager.signOut() }
            }
        case .loaded(let projects):
            if projects.isEmpty {
                EmptyStateView(
                    title: "No Firebase projects",
                    message: "This Google account doesn’t have any Firebase projects yet, or the Firebase Management API isn’t enabled. Create a project in the Firebase console, then try again.",
                    systemImage: "square.stack.3d.up.slash",
                    actionTitle: "Try again"
                ) {
                    Task { await model.load() }
                }
            } else if model.displayedProjects.isEmpty {
                EmptyStateView(
                    title: "No matches",
                    message: "No projects match “\(model.searchText)”.",
                    systemImage: "magnifyingglass",
                    actionTitle: "Clear search"
                ) {
                    model.searchText = ""
                }
            } else {
                projectList(model)
            }
        }
    }

    private func projectList(_ model: ProjectsViewModel) -> some View {
        @Bindable var model = model
        return List {
            if let account = env.accountManager.activeAccount {
                Section {
                    HStack(spacing: Theme.Spacing.md) {
                        Circle()
                            .fill(Theme.Palette.surfaceRaised)
                            .frame(width: 36, height: 36)
                            .overlay(
                                Text(account.initials)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Theme.Palette.textPrimary)
                            )
                        VStack(alignment: .leading, spacing: 2) {
                            Text(account.displayName ?? account.email)
                                .font(.pcBodyEmphasis)
                                .foregroundStyle(Theme.Palette.textPrimary)
                                .lineLimit(1)
                            Text(account.email)
                                .font(.pcCaption)
                                .foregroundStyle(Theme.Palette.textSecondary)
                                .lineLimit(1)
                        }
                        Spacer()
                        Button("Switch") { showingAccountSheet = true }
                            .font(.pcCaption)
                    }
                    .listRowBackground(Theme.Palette.surface)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Signed in as \(account.email)")
                }
            }

            Section {
                ForEach(model.displayedProjects) { project in
                    Button {
                        open(project, model: model)
                    } label: {
                        ProjectRow(
                            project: project,
                            environment: model.environment(for: project),
                            isPinned: model.isPinned(project)
                        )
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .leading) {
                        Button {
                            model.togglePin(project)
                        } label: {
                            Label(model.isPinned(project) ? "Unpin" : "Pin",
                                  systemImage: model.isPinned(project) ? "pin.slash" : "pin")
                        }
                        .tint(Theme.Palette.accent)
                    }
                    .contextMenu { environmentMenu(project, model: model) }
                    .listRowBackground(Theme.Palette.surface)
                    .accessibilityIdentifier("projects.row.\(project.projectId)")
                }
            } header: {
                Text("\(model.connectedCount) projects • \(model.activeCount) active • \(model.productionCount) production")
                    .font(.pcCaption)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .searchable(text: $model.searchText, prompt: "Search name, ID, or number")
        .refreshable { await model.refresh() }
    }

    @ViewBuilder
    private func environmentMenu(_ project: FirebaseProject, model: ProjectsViewModel) -> some View {
        Picker("Label", selection: Binding(
            get: { model.environment(for: project) },
            set: { model.setEnvironment($0, for: project) }
        )) {
            ForEach(ProjectEnvironment.allCases) { env in
                Text(env.title).tag(env)
            }
        }
        Button(model.isPinned(project) ? "Unpin" : "Pin") { model.togglePin(project) }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                if let model {
                    Picker("Sort", selection: Binding(
                        get: { model.sortOrder },
                        set: { model.sortOrder = $0 }
                    )) {
                        ForEach(ProjectsViewModel.SortOrder.allCases) { Text($0.rawValue).tag($0) }
                    }
                }
            } label: {
                Image(systemName: "arrow.up.arrow.down")
            }
            .accessibilityLabel("Sort projects")
        }
        ToolbarItem(placement: .topBarLeading) {
            Button {
                showingAccountSheet = true
            } label: {
                AccountBadge()
            }
            .accessibilityLabel("Account switcher")
        }
    }

    private func open(_ project: FirebaseProject, model: ProjectsViewModel) {
        guard let account = env.accountManager.activeAccount else { return }
        if !env.featureGate.canOpenProject(id: project.projectId, freeProjectID: env.freeTierProjectID) {
            showProGate = true
            return
        }
        env.open(
            project: project,
            environment: model.environment(for: project),
            accountID: account.id
        )
    }
}

/// Compact project row: name, ID, number, lifecycle, environment.
struct ProjectRow: View {
    let project: FirebaseProject
    let environment: ProjectEnvironment
    let isPinned: Bool

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(environment.accentColor.opacity(0.18))
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: "bolt.horizontal.fill")
                        .foregroundStyle(environment.accentColor)
                )
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(project.name)
                        .font(.pcBodyEmphasis)
                        .foregroundStyle(Theme.Palette.textPrimary)
                        .lineLimit(1)
                    if isPinned {
                        Image(systemName: "pin.fill")
                            .font(.caption2)
                            .foregroundStyle(Theme.Palette.textTertiary)
                            .accessibilityLabel("Pinned")
                    }
                }
                Text(project.projectId)
                    .font(.pcMonoSmall)
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    if let number = project.projectNumber {
                        Text("#\(number)")
                            .font(.pcCaption)
                            .foregroundStyle(Theme.Palette.textTertiary)
                    }
                    Text(project.lifecycleDisplay)
                        .font(.pcCaption)
                        .foregroundStyle(project.isActive ? Theme.Palette.healthy : Theme.Palette.textTertiary)
                    if let region = project.regionDisplay {
                        Text("• \(region)")
                            .font(.pcCaption)
                            .foregroundStyle(Theme.Palette.textTertiary)
                            .lineLimit(1)
                    }
                }
            }
            Spacer(minLength: 8)
            if environment != .unlabeled {
                Text(environment.shortTitle)
                    .font(.pcLabel)
                    .foregroundStyle(environment.accentColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(environment.accentColor.opacity(0.15), in: Capsule())
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }

    private var accessibilityDescription: String {
        var parts = [project.name, project.projectId, project.lifecycleDisplay]
        if let number = project.projectNumber { parts.append("number \(number)") }
        if environment != .unlabeled { parts.append(environment.title) }
        if isPinned { parts.append("pinned") }
        return parts.joined(separator: ", ")
    }
}

struct AccountBadge: View {
    @Environment(AppEnvironment.self) private var env

    var body: some View {
        if let account = env.accountManager.activeAccount {
            Circle()
                .fill(Theme.Palette.surfaceRaised)
                .frame(width: 30, height: 30)
                .overlay(
                    Text(account.initials)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.Palette.textPrimary)
                )
                .accessibilityLabel("Account \(account.email)")
        }
    }
}
