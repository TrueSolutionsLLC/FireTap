import SwiftUI

/// Activity tab shell — hosts the Incident Center for the open project.
struct ActivityView: View {
    let project: FirebaseProject

    var body: some View {
        NavigationStack {
            IncidentCenterView(project: project)
                .appBackground()
        }
    }
}

struct IncidentDetailView: View {
    let incident: Incident

    var body: some View {
        List {
            Section("Incident") {
                LabeledContent("Severity", value: incident.severity)
                LabeledContent("Source", value: incident.sourceModule)
                LabeledContent("Resource", value: incident.resource)
                Text(incident.detail)
                    .font(.pcBody)
                    .textSelection(.enabled)
            }
            .listRowBackground(Theme.Palette.surface)
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .appBackground()
        .navigationTitle(incident.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
