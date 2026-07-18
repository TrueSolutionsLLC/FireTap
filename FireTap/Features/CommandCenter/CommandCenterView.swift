import SwiftUI

/// Figma "03 — Command Center". Shows real project facts (identity, apps,
/// resources) and quick links. Live metric cards (Firestore reads, function
/// failures, etc.) are populated by their backing monitoring APIs and show
/// honest per-card permission/availability states — never fabricated numbers.
struct CommandCenterView: View {
    let project: FirebaseProject
    @Environment(AppEnvironment.self) private var env
    @State private var appsPhase: AsyncPhase<[FirebaseAppInfo]> = .idle

    private var accountID: String? { env.accountManager.activeAccountID }

    private var favorites: [String] {
        guard let accountID else { return [] }
        return env.preferences.favoriteResourceKeys(account: accountID).sorted()
    }

    private var recentlyViewed: [String] {
        guard let accountID else { return [] }
        return env.preferences.recentlyViewedResourceKeys(account: accountID)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    header
                    statusRow
                    if !favorites.isEmpty || !recentlyViewed.isEmpty {
                        shortcutsSection
                    }
                    resourcesCard
                    metricsSection
                    quickActions
                }
                .padding(Theme.Spacing.xl)
            }
            .appBackground()
            .navigationTitle("Command Center")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        env.closeProject()
                    } label: {
                        Label("Projects", systemImage: "chevron.left")
                    }
                }
            }
            .refreshable { await loadApps() }
        }
        .task { await loadApps() }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(project.name)
                    .font(.pcTitle)
                    .foregroundStyle(Theme.Palette.textPrimary)
                Text(project.projectId)
                    .font(.pcMonoSmall)
                    .foregroundStyle(Theme.Palette.textSecondary)
            }
            Spacer()
            environmentBadge
        }
    }

    private var environmentBadge: some View {
        StatusChip(
            text: env.selectedProjectEnvironment.shortTitle,
            systemImage: env.selectedProjectEnvironment.isProduction ? "exclamationmark.shield.fill" : "tag.fill",
            color: env.selectedProjectEnvironment.accentColor,
            container: env.selectedProjectEnvironment.accentColor.opacity(0.18)
        )
        .accessibilityLabel("Project environment: \(env.selectedProjectEnvironment.title)")
        .accessibilityHint(env.selectedProjectEnvironment.isProduction ? "Production projects use read-only Safe Mode by default" : "Environment label for this project")
    }

    private var statusRow: some View {
        HStack(spacing: Theme.Spacing.sm) {
            if env.selectedProjectEnvironment.isProduction {
                safeModeChip
            }
            NavigationLink {
                IncidentCenterView(project: project)
            } label: {
                StatusChip(
                    text: "Incidents",
                    systemImage: "exclamationmark.triangle.fill",
                    color: Theme.Palette.warning,
                    container: Theme.Palette.warningContainer
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Incident Center")
            .accessibilityHint("View function failures, critical logs, and audit events")
        }
    }

    private var safeModeChip: some View {
        let unlocked = env.safeMode.isWriteUnlocked
        return StatusChip(
            text: unlocked ? "UNLOCKED" : "LOCKED",
            systemImage: unlocked ? "lock.open.fill" : "lock.fill",
            color: unlocked ? Theme.Palette.warning : Theme.Palette.healthy,
            container: unlocked ? Theme.Palette.warningContainer : Theme.Palette.healthyContainer
        )
        .accessibilityLabel(unlocked ? "Safe Mode write access unlocked" : "Safe Mode write access locked")
        .accessibilityHint(unlocked ? "Write access will relock after inactivity" : "Production writes require biometric unlock")
    }

    @ViewBuilder
    private var shortcutsSection: some View {
        if !favorites.isEmpty {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                SectionHeader(title: "Favorites")
                Card {
                    VStack(spacing: 0) {
                        ForEach(favorites, id: \.self) { key in
                            resourceShortcutRow(key)
                            if key != favorites.last {
                                Divider()
                            }
                        }
                    }
                }
            }
        }

        if !recentlyViewed.isEmpty {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                SectionHeader(title: "Recently viewed")
                Card {
                    VStack(spacing: 0) {
                        ForEach(recentlyViewed, id: \.self) { key in
                            resourceShortcutRow(key)
                            if key != recentlyViewed.last {
                                Divider()
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func resourceShortcutRow(_ key: String) -> some View {
        if let module = ResourceKey.serviceModule(for: key) {
            NavigationLink {
                ServiceModuleView(module: module, project: project)
            } label: {
                Label(ResourceKey.displayTitle(for: key), systemImage: module.symbol)
                    .font(.pcBody)
                    .foregroundStyle(Theme.Palette.textPrimary)
                    .padding(.vertical, Theme.Spacing.sm)
            }
        } else {
            Text(ResourceKey.displayTitle(for: key))
                .font(.pcBody)
                .foregroundStyle(Theme.Palette.textSecondary)
                .padding(.vertical, Theme.Spacing.sm)
        }
    }

    private var resourcesCard: some View {
        Card {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                Text("Project")
                    .font(.pcLabel)
                    .foregroundStyle(Theme.Palette.textSecondary)
                factRow("Project number", project.projectNumber ?? "—")
                factRow("Default location", project.regionDisplay ?? "Not set")
                appsRow
                if let bucket = project.resources?.storageBucket {
                    factRow("Storage bucket", bucket)
                }
            }
        }
    }

    private var appsRow: some View {
        HStack {
            Text("Registered apps").font(.pcCaption).foregroundStyle(Theme.Palette.textSecondary)
            Spacer()
            switch appsPhase {
            case .idle, .loading:
                ProgressView().controlSize(.small)
            case .failed(let error):
                Text(error.userMessage == APIError.permissionDenied(message: nil).userMessage ? "No access" : "Unavailable")
                    .font(.pcCaption).foregroundStyle(Theme.Palette.textTertiary)
            case .loaded(let apps):
                Text("\(apps.count)").font(.pcBodyEmphasis).foregroundStyle(Theme.Palette.textPrimary)
            }
        }
    }

    private func factRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(.pcCaption).foregroundStyle(Theme.Palette.textSecondary)
            Spacer()
            Text(value).font(.pcCaption).foregroundStyle(Theme.Palette.textPrimary).lineLimit(1)
        }
    }

    private var metricsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SectionHeader(title: "Live metrics")
            Card {
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    NavigationLink {
                        MonitoringMetricsView(project: project)
                    } label: {
                        Label("Cloud Functions monitoring", systemImage: "chart.line.uptrend.xyaxis")
                            .font(.pcBodyEmphasis)
                    }
                    NavigationLink {
                        CostGuardView(project: project)
                    } label: {
                        Label("Cost Guard (session usage)", systemImage: "gauge.with.dots.needle.33percent")
                            .font(.pcBodyEmphasis)
                    }
                    Text("Metrics load from Cloud Monitoring when permitted. Cost Guard tracks Firestore operations from this session only.")
                        .font(.pcCaption)
                        .foregroundStyle(Theme.Palette.textSecondary)
                }
            }
        }
    }

    private var quickActions: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SectionHeader(title: "Quick actions")
            let columns = [GridItem(.adaptive(minimum: 88), spacing: Theme.Spacing.md)]
            LazyVGrid(columns: columns, spacing: Theme.Spacing.md) {
                ForEach([ServiceModule.firestore, .authentication, .functions, .storage]) { module in
                    NavigationLink {
                        ServiceModuleView(module: module, project: project)
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: module.symbol)
                                .font(.title2)
                                .foregroundStyle(module.tint)
                            Text(module.title)
                                .font(.pcCaption)
                                .foregroundStyle(Theme.Palette.textPrimary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Theme.Spacing.lg)
                        .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(module.title) module")
                    .accessibilityHint("Opens the \(module.title) service browser")
                }
            }
        }
    }

    private func loadApps() async {
        appsPhase = .loading
        do {
            let apps = try await env.projectsService.listApps(projectID: project.projectId)
            appsPhase = .loaded(apps)
        } catch let error as APIError {
            appsPhase = .failed(error)
        } catch {
            appsPhase = .failed(.transport(underlying: "unknown"))
        }
    }
}
