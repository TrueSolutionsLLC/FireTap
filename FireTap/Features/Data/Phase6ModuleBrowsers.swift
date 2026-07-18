import SwiftUI

struct RulesBrowserView: View {
    let project: FirebaseProject
    @Environment(AppEnvironment.self) private var env
    @State private var product: RulesProduct = .firestore
    @State private var phase: AsyncPhase<RulesBrowserSnapshot> = .idle

    var body: some View {
        Group {
            switch phase {
            case .idle, .loading:
                LoadingStateView().padding()
            case .failed(let error):
                ErrorStateView(error: error) { Task { await load(force: true) } }
            case .loaded(let snapshot):
                List {
                    Section {
                        Picker("Product", selection: $product) {
                            ForEach(RulesProduct.allCases) { item in
                                Text(item.title).tag(item)
                            }
                        }
                        .onChange(of: product) { _, _ in Task { await load(force: true) } }

                        CardUnavailableNote(
                            message: "Rules publish is read-only in this build. Publishing requires createRuleset + release with server-side validation; FireTap shows active rules and history only.",
                            systemImage: "lock.doc"
                        )
                    }

                    Section("Active release • \(snapshot.release?.releaseID ?? "—")") {
                        if let release = snapshot.release {
                            LabeledContent("Ruleset", value: release.rulesetName?.split(separator: "/").last.map(String.init) ?? "—")
                            if let updateTime = release.updateTime ?? release.createTime {
                                LabeledContent("Updated", value: updateTime)
                            }
                        } else {
                            Text("No release found for this product.")
                                .foregroundStyle(Theme.Palette.textSecondary)
                        }
                    }

                    Section("Active rules") {
                        if let text = snapshot.activeRulesText, !text.isEmpty {
                            Text(text)
                                .font(.pcMonoSmall)
                                .textSelection(.enabled)
                        } else {
                            Text("No rules text returned for the active release.")
                                .foregroundStyle(Theme.Palette.textSecondary)
                        }
                    }

                    Section("Ruleset history • \(snapshot.history.count)") {
                        if snapshot.history.isEmpty {
                            Text("No rulesets listed.")
                                .foregroundStyle(Theme.Palette.textSecondary)
                        }
                        ForEach(snapshot.history) { ruleset in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(ruleset.rulesetID)
                                    .font(.pcBodyEmphasis)
                                if let createTime = ruleset.createTime {
                                    Text(createTime)
                                        .font(.pcCaption)
                                        .foregroundStyle(Theme.Palette.textSecondary)
                                }
                            }
                            .listRowBackground(Theme.Palette.surface)
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .refreshable { await load(force: true) }
            }
        }
        .appBackground()
        .navigationTitle("Security Rules")
        .task { if phase.value == nil { await load(force: false) } }
    }

    private func load(force: Bool) async {
        if force || phase.value == nil { phase = .loading }
        do {
            let releaseID = product.releaseName(
                projectID: project.projectId,
                storageBucket: project.resources?.storageBucket,
                databaseInstance: project.resources?.realtimeDatabaseInstance
            )
            let releases = try await env.rulesService.listReleases(
                projectID: project.projectId,
                pageSize: 50,
                pageToken: nil
            )
            var matchingRelease = releases.releases?.first { $0.releaseID == releaseID }
            if matchingRelease == nil {
                do {
                    matchingRelease = try await env.rulesService.getRelease(
                        projectID: project.projectId,
                        releaseID: releaseID
                    )
                } catch APIError.notFound {
                    matchingRelease = nil
                }
            }

            var activeText: String?
            if let rulesetName = matchingRelease?.rulesetName {
                let ruleset = try await env.rulesService.getRuleset(name: rulesetName)
                activeText = ruleset.rulesText
            }

            let rulesets = try await env.rulesService.listRulesets(
                projectID: project.projectId,
                pageSize: 25,
                pageToken: nil
            )
            phase = .loaded(
                RulesBrowserSnapshot(
                    release: matchingRelease,
                    activeRulesText: activeText,
                    history: rulesets.rulesets ?? []
                )
            )
        } catch let error as APIError {
            phase = .failed(error)
        } catch {
            phase = .failed(.transport(underlying: "unknown"))
        }
    }
}

private struct RulesBrowserSnapshot: Sendable, Equatable {
    let release: RulesRelease?
    let activeRulesText: String?
    let history: [Ruleset]
}

struct AppDistributionBrowserView: View {
    let project: FirebaseProject
    @Environment(AppEnvironment.self) private var env
    @State private var phase: AsyncPhase<AppDistributionSnapshot> = .idle

    var body: some View {
        Group {
            switch phase {
            case .idle, .loading:
                LoadingStateView().padding()
            case .failed(let error):
                ErrorStateView(error: error) { Task { await load() } }
            case .loaded(let snapshot):
                if snapshot.apps.isEmpty && snapshot.groups.isEmpty {
                    EmptyStateView(
                        title: "No App Distribution data",
                        message: "No apps or tester groups were returned. The App Distribution API may be disabled or your account may lack firebaseappdistro viewer access.",
                        systemImage: "paperplane",
                        actionTitle: "Retry"
                    ) { Task { await load() } }
                } else {
                    List {
                        Section("Apps • \(snapshot.apps.count)") {
                            if snapshot.apps.isEmpty {
                                Text("No apps registered for App Distribution.")
                                    .foregroundStyle(Theme.Palette.textSecondary)
                            }
                            ForEach(snapshot.apps) { app in
                                NavigationLink {
                                    AppDistributionReleasesView(project: project, app: app)
                                } label: {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(app.displayName ?? app.resolvedAppID)
                                            .font(.pcBodyEmphasis)
                                        Text(app.resolvedAppID)
                                            .font(.pcCaption)
                                            .foregroundStyle(Theme.Palette.textSecondary)
                                            .lineLimit(1)
                                    }
                                }
                                .listRowBackground(Theme.Palette.surface)
                            }
                        }
                        Section("Tester groups • \(snapshot.groups.count)") {
                            if snapshot.groups.isEmpty {
                                Text("No tester groups returned.")
                                    .foregroundStyle(Theme.Palette.textSecondary)
                            }
                            ForEach(snapshot.groups) { group in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(group.displayName ?? group.groupID)
                                        .font(.pcBodyEmphasis)
                                    Text("\(group.testerCount ?? 0) testers · \(group.releaseCount ?? 0) releases")
                                        .font(.pcCaption)
                                        .foregroundStyle(Theme.Palette.textSecondary)
                                }
                                .listRowBackground(Theme.Palette.surface)
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                    .refreshable { await load() }
                }
            }
        }
        .appBackground()
        .navigationTitle("App Distribution")
        .task { if phase.value == nil { await load() } }
    }

    private func load() async {
        if phase.value == nil { phase = .loading }
        guard let number = project.projectNumber else {
            phase = .failed(.notFound(message: "Project number is required for App Distribution API calls."))
            return
        }
        do {
            async let apps = env.appDistributionService.listApps(projectNumber: number, pageSize: 50, pageToken: nil)
            async let groups = env.appDistributionService.listGroups(projectNumber: number, pageSize: 50, pageToken: nil)
            phase = .loaded(
                AppDistributionSnapshot(
                    apps: try await apps.apps ?? [],
                    groups: try await groups.groups ?? []
                )
            )
        } catch let error as APIError {
            phase = .failed(error)
        } catch {
            phase = .failed(.transport(underlying: "unknown"))
        }
    }
}

private struct AppDistributionSnapshot: Sendable, Equatable {
    let apps: [AppDistributionApp]
    let groups: [AppDistributionGroup]
}

private struct AppDistributionReleasesView: View {
    let project: FirebaseProject
    let app: AppDistributionApp
    @Environment(AppEnvironment.self) private var env
    @State private var phase: AsyncPhase<[AppDistributionRelease]> = .idle

    var body: some View {
        Group {
            switch phase {
            case .idle, .loading:
                LoadingStateView().padding()
            case .failed(let error):
                ErrorStateView(error: error) { Task { await load() } }
            case .loaded(let releases):
                List {
                    if releases.isEmpty {
                        Text("No releases for this app.")
                            .foregroundStyle(Theme.Palette.textSecondary)
                    }
                    ForEach(releases) { release in
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(release.displayVersion ?? "?") (\(release.buildVersion ?? "?"))")
                                .font(.pcBodyEmphasis)
                            if let notes = release.releaseNotes?.text, !notes.isEmpty {
                                Text(notes)
                                    .font(.pcCaption)
                                    .foregroundStyle(Theme.Palette.textSecondary)
                                    .lineLimit(3)
                            }
                            if let createTime = release.createTime {
                                Text(createTime)
                                    .font(.pcCaption)
                                    .foregroundStyle(Theme.Palette.textTertiary)
                            }
                        }
                        .listRowBackground(Theme.Palette.surface)
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .refreshable { await load() }
            }
        }
        .appBackground()
        .navigationTitle(app.displayName ?? "Releases")
        .task { if phase.value == nil { await load() } }
    }

    private func load() async {
        if phase.value == nil { phase = .loading }
        guard let number = project.projectNumber else {
            phase = .failed(.notFound(message: "Project number is required."))
            return
        }
        do {
            let response = try await env.appDistributionService.listReleases(
                projectNumber: number,
                appID: app.resolvedAppID,
                pageSize: 50,
                pageToken: nil
            )
            phase = .loaded(response.releases ?? [])
        } catch let error as APIError {
            phase = .failed(error)
        } catch {
            phase = .failed(.transport(underlying: "unknown"))
        }
    }
}

struct ExtensionsBrowserView: View {
    let project: FirebaseProject
    @Environment(AppEnvironment.self) private var env

    var body: some View {
        LiveServiceListView(
            title: "Extensions",
            symbol: "puzzlepiece.extension.fill",
            emptyTitle: "No extension instances",
            emptyMessage: "No installed Firebase Extensions were returned. The Extensions API may be disabled or your account may lack firebaseextensions.instances.list.",
            load: { try await env.extensionsService.listInstances(projectID: project.projectId, pageSize: 100, pageToken: nil).instances ?? [] }
        ) { instance in
            VStack(alignment: .leading, spacing: 2) {
                Text(instance.extensionDisplayName)
                    .font(.pcBodyEmphasis)
                Text("\(instance.instanceID) · \(instance.state ?? "state?")")
                    .font(.pcCaption)
                    .foregroundStyle(Theme.Palette.textSecondary)
                if let version = instance.extensionVersion {
                    Text("v\(version)")
                        .font(.pcCaption)
                        .foregroundStyle(Theme.Palette.textTertiary)
                }
            }
        }
    }
}
