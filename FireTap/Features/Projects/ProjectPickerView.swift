import SwiftUI

/// Figma "02 — Projects": the account's real Firebase projects with search,
/// sort, pin, and environment labels. Selecting a project enters the console.
struct ProjectPickerView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var model: ProjectsViewModel?

    var body: some View {
        NavigationStack {
            Group {
                if let model {
                    content(model)
                } else {
                    LoadingStateView().padding()
                }
            }
            .appBackground()
            .navigationTitle("Projects")
            .toolbar { toolbar }
        }
        .task {
            if model == nil, let account = env.accountManager.activeAccount {
                let vm = ProjectsViewModel(
                    projectsService: env.projectsService,
                    preferences: env.preferences,
                    accountID: account.id
                )
                model = vm
                await vm.load()
            }
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
                Task { await env.accountManager.setActiveAccount(nil) }
            }
        case .loaded(let projects):
            if projects.isEmpty {
                EmptyStateView(
                    title: "No Firebase projects",
                    message: "This Google account doesn't have any Firebase projects yet, or the Firebase Management API isn't enabled for it.",
                    systemImage: "square.stack.3d.up.slash"
                )
            } else {
                projectList(model)
            }
        }
    }

    private func projectList(_ model: ProjectsViewModel) -> some View {
        @Bindable var model = model
        return List {
            Section {
                ForEach(model.displayedProjects) { project in
                    ProjectRow(
                        project: project,
                        environment: model.environment(for: project),
                        isPinned: model.isPinned(project)
                    )
                    .contentShape(Rectangle())
                    .onTapGesture { open(project, model: model) }
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
                }
            } header: {
                Text("\(model.connectedCount) connected • \(model.productionCount) production")
                    .font(.pcCaption)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .searchable(text: $model.searchText, prompt: "Search projects")
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
        }
        ToolbarItem(placement: .topBarLeading) {
            AccountBadge()
        }
    }

    private func open(_ project: FirebaseProject, model: ProjectsViewModel) {
        guard let account = env.accountManager.activeAccount else { return }
        env.open(
            project: project,
            environment: model.environment(for: project),
            accountID: account.id
        )
    }
}

/// Compact project row matching the Figma density.
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
                    }
                }
                Text(project.projectId)
                    .font(.pcMonoSmall)
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .lineLimit(1)
            }
            Spacer()
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
        .accessibilityLabel("\(project.name), \(project.projectId), \(environment.title)")
    }
}

/// Small circular account initials badge used in navigation bars.
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
