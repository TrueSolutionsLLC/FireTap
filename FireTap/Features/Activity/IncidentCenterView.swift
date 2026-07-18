import SwiftUI

/// Incident Center — aggregates real function failures, critical logs, and
/// local audit entries with navigation to source modules where possible.
struct IncidentCenterView: View {
    let project: FirebaseProject
    @Environment(AppEnvironment.self) private var env
    @State private var phase: AsyncPhase<[Incident]> = .idle

    var body: some View {
        Group {
            switch phase {
            case .idle, .loading:
                LoadingStateView().padding()
            case .failed(let error):
                ErrorStateView(error: error) { Task { await load() } }
            case .loaded(let incidents):
                if incidents.isEmpty {
                    EmptyStateView(
                        title: "No incidents",
                        message: "No function failures, critical logs, or recent FireTap audit events were found for \(project.name).",
                        systemImage: "checkmark.shield",
                        actionTitle: "Refresh"
                    ) { Task { await load() } }
                } else {
                    List {
                        Section("\(incidents.count) signals") {
                            ForEach(incidents) { incident in
                                incidentRow(incident)
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
        .navigationTitle("Incident Center")
        .task { if phase.value == nil { await load() } }
    }

    @ViewBuilder
    private func incidentRow(_ incident: Incident) -> some View {
        if let module = sourceModule(for: incident) {
            NavigationLink {
                ServiceModuleView(module: module, project: project)
            } label: {
                incidentLabel(incident)
            }
        } else {
            NavigationLink {
                IncidentDetailView(incident: incident)
            } label: {
                incidentLabel(incident)
            }
        }
    }

    private func incidentLabel(_ incident: Incident) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(incident.severity)
                    .font(.pcLabel)
                    .foregroundStyle(severityColor(incident.severity))
                Spacer()
                Text(incident.sourceModule)
                    .font(.pcCaption)
                    .foregroundStyle(Theme.Palette.textTertiary)
            }
            Text(incident.title)
                .font(.pcBodyEmphasis)
                .foregroundStyle(Theme.Palette.textPrimary)
            Text(incident.detail)
                .font(.pcCaption)
                .foregroundStyle(Theme.Palette.textSecondary)
                .lineLimit(2)
        }
    }

    private func sourceModule(for incident: Incident) -> ServiceModule? {
        switch incident.sourceModule {
        case "functions": return .functions
        case "logs": return .logs
        default: return nil
        }
    }

    private func severityColor(_ severity: String) -> Color {
        switch severity.uppercased() {
        case "AUDIT": return Theme.Palette.info
        case "WARNING": return Theme.Palette.warning
        default: return Theme.Palette.danger
        }
    }

    private func load() async {
        if phase.value == nil { phase = .loading }
        do {
            async let functions = env.functionsService.listFunctions(projectID: project.projectId)
            async let logs = env.loggingService.listEntries(
                projectID: project.projectId,
                filter: LoggingFilter.build(severityAtLeast: "ERROR"),
                pageSize: 40,
                pageToken: nil
            )
            let audit = await env.audit.entries(limit: 40)
            let incidents = IncidentAggregator.aggregate(
                functionErrors: try await functions,
                logEntries: try await logs.entries,
                auditEntries: audit
            )
            phase = .loaded(incidents)
        } catch let error as APIError {
            let audit = await env.audit.entries(limit: 40)
            if !audit.isEmpty {
                phase = .loaded(IncidentAggregator.aggregate(functionErrors: [], logEntries: [], auditEntries: audit))
            } else {
                phase = .failed(error)
            }
        } catch {
            phase = .failed(.transport(underlying: "unknown"))
        }
    }
}
