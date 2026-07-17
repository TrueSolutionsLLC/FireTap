import SwiftUI

/// Incident Center. Aggregates signals from Functions, Logging, App Check,
/// Auth, Storage/Firestore usage and Billing into one feed. Until those source
/// modules are connected it shows an honest state rather than inventing alerts.
struct ActivityView: View {
    let project: FirebaseProject

    var body: some View {
        NavigationStack {
            ContentUnavailableView {
                Label("Incident Center", systemImage: "dot.radiowaves.up.forward")
            } description: {
                VStack(spacing: Theme.Spacing.sm) {
                    Text("Incidents are aggregated from Cloud Functions errors, Cloud Logging, App Check, Authentication activity, and usage anomalies for \(project.name).")
                    Text("No incidents are shown until those signals are read from Google. This build does not fabricate alerts.")
                        .font(.pcCaption)
                        .foregroundStyle(Theme.Palette.textSecondary)
                }
            }
            .appBackground()
            .navigationTitle("Activity")
        }
    }
}
