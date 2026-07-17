import SwiftUI

/// Figma "03 — Command Center". Shows real project facts (identity, apps,
/// resources) and quick links. Live metric cards (Firestore reads, function
/// failures, etc.) are populated by their backing monitoring APIs and show
/// honest per-card permission/availability states — never fabricated numbers.
struct CommandCenterView: View {
    let project: FirebaseProject
    @Environment(AppEnvironment.self) private var env
    @State private var appsPhase: AsyncPhase<[FirebaseAppInfo]> = .idle

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    header
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
            if env.selectedProjectEnvironment.isProduction {
                StatusChip(text: "SAFE", systemImage: "lock.fill",
                           color: Theme.Palette.healthy, container: Theme.Palette.healthyContainer)
            }
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
                CardUnavailableNote(
                    message: "Metrics for Firestore, Functions and Auth are read from Cloud Monitoring inside each module. Open a module under Data to view its live figures. No numbers are shown here until they load from Google.",
                    systemImage: "chart.line.uptrend.xyaxis"
                )
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
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Theme.Spacing.lg)
                        .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous))
                    }
                    .buttonStyle(.plain)
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
