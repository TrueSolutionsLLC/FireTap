import SwiftUI

/// Live Firebase Authentication user directory. Paginated via the Identity
/// Toolkit `accounts:batchGet` endpoint, with server-side lookup for search by
/// email, phone, or UID. Read-only in this build — no fake write controls.
struct AuthUsersView: View {
    let project: FirebaseProject
    @Environment(AppEnvironment.self) private var env
    @State private var model: AuthUsersViewModel?

    var body: some View {
        Group {
            if let model {
                content(model)
            } else {
                LoadingStateView().padding()
            }
        }
        .appBackground()
        .navigationTitle("Authentication")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if model == nil {
                let vm = AuthUsersViewModel(projectID: project.projectId, service: env.authService)
                model = vm
                await vm.loadFirstPage()
            }
        }
    }

    @ViewBuilder
    private func content(_ model: AuthUsersViewModel) -> some View {
        @Bindable var model = model
        List {
            summarySection(model)

            if let error = model.error {
                Section {
                    ErrorStateView(error: error) { Task { await model.loadFirstPage() } }
                        .listRowBackground(Color.clear)
                }
            }

            if model.isSearching {
                Section { HStack { ProgressView(); Text("Searching…") }.listRowBackground(Theme.Palette.surface) }
            } else if model.searchMatch != nil || model.searchMissed {
                searchResultsSection(model)
            } else {
                usersSection(model)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .searchable(text: $model.searchText, prompt: "Search by email, phone, or UID")
        .onSubmit(of: .search) { Task { await model.runSearch() } }
        .onChange(of: model.searchText) { _, newValue in
            if newValue.trimmingCharacters(in: .whitespaces).isEmpty { model.clearSearch() }
        }
        .refreshable { await model.loadFirstPage() }
    }

    private func summarySection(_ model: AuthUsersViewModel) -> some View {
        @Bindable var model = model
        return Section {
            HStack {
                Label("Total users", systemImage: "person.2.fill").foregroundStyle(Theme.Palette.textSecondary)
                Spacer()
                Text(model.totalCount.map(String.init) ?? "—")
                    .font(.pcBodyEmphasis)
                    .foregroundStyle(Theme.Palette.textPrimary)
            }
            .listRowBackground(Theme.Palette.surface)

            Picker("Filter", selection: $model.filter) {
                ForEach(AuthUsersViewModel.Filter.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .listRowBackground(Theme.Palette.surface)
        } footer: {
            Text("Filters apply to the users loaded so far. Search queries the full directory directly.")
        }
    }

    @ViewBuilder
    private func searchResultsSection(_ model: AuthUsersViewModel) -> some View {
        if let match = model.searchMatch {
            Section("Search result") {
                userRow(match).listRowBackground(Theme.Palette.surface)
            }
        } else {
            Section {
                EmptyStateView(
                    title: "No match",
                    message: "No user found for “\(model.searchText)”. Search is exact by email, phone (E.164), or UID.",
                    systemImage: "person.fill.questionmark"
                )
                .listRowBackground(Color.clear)
            }
        }
    }

    @ViewBuilder
    private func usersSection(_ model: AuthUsersViewModel) -> some View {
        let shown = model.displayedUsers
        Section("Users • \(shown.count) loaded") {
            if model.hasLoadedOnce && shown.isEmpty {
                Text(model.filter == .all
                     ? "No users in this project, or your account can't read them."
                     : "No loaded users match the \(model.filter.title.lowercased()) filter.")
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .listRowBackground(Theme.Palette.surface)
            }
            ForEach(shown) { user in
                NavigationLink {
                    AuthUserDetailView(user: user)
                } label: {
                    userRow(user)
                }
                .listRowBackground(Theme.Palette.surface)
            }
            paginationRow(model)
        }
    }

    @ViewBuilder
    private func paginationRow(_ model: AuthUsersViewModel) -> some View {
        if !model.reachedEnd {
            Button {
                Task { await model.loadNextPage() }
            } label: {
                HStack {
                    if model.isLoading { ProgressView() }
                    Text(model.isLoading ? "Loading…" : "Load next \(model.pageSize)")
                }
            }
            .disabled(model.isLoading)
            .listRowBackground(Theme.Palette.surface)
        } else if model.hasLoadedOnce {
            Text("End of user list reached.")
                .font(.pcCaption)
                .foregroundStyle(Theme.Palette.textTertiary)
                .listRowBackground(Theme.Palette.surface)
        }
    }

    private func userRow(_ user: AuthUser) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(user.primaryLabel)
                    .font(.pcBodyEmphasis)
                    .foregroundStyle(Theme.Palette.textPrimary)
                    .lineLimit(1)
                Spacer()
                if user.isDisabled {
                    StatusChip(text: "Disabled", systemImage: "nosign",
                               color: Theme.Palette.danger, container: Theme.Palette.dangerContainer)
                } else if user.emailVerified == true {
                    StatusChip(text: "Verified", systemImage: "checkmark.seal.fill")
                }
            }
            HStack(spacing: 6) {
                Text(user.localId)
                    .font(.pcMonoSmall)
                    .foregroundStyle(Theme.Palette.textTertiary)
                    .lineLimit(1)
                if !user.providerLabels.isEmpty {
                    Text("•").foregroundStyle(Theme.Palette.textTertiary)
                    Text(user.providerLabels.joined(separator: ", "))
                        .font(.pcCaption)
                        .foregroundStyle(Theme.Palette.textSecondary)
                        .lineLimit(1)
                }
            }
        }
    }
}
