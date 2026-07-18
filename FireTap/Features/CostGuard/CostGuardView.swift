import SwiftUI

/// Session-level usage counters and honest notes about live cloud billing.
struct CostGuardView: View {
    let project: FirebaseProject?
    @Environment(AppEnvironment.self) private var env

    private var usage: SessionUsage { env.sessionUsage }

    var body: some View {
        List {
            sessionSection
            thresholdsSection
            billingSection
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .appBackground()
        .navigationTitle("Cost Guard")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var sessionSection: some View {
        Section {
            if let project {
                LabeledContent("Project", value: project.name)
                    .listRowBackground(Theme.Palette.surface)
            }
            LabeledContent("Firestore reads (this session)", value: "\(usage.firestoreReads)")
                .listRowBackground(Theme.Palette.surface)
            LabeledContent("Firestore writes (this session)", value: "\(usage.firestoreWrites)")
                .listRowBackground(Theme.Palette.surface)
            LabeledContent("Firestore deletes (this session)", value: "\(usage.firestoreDeletes)")
                .listRowBackground(Theme.Palette.surface)
        } header: {
            Text("Session usage")
        } footer: {
            Text("Counters reflect Firestore operations initiated by FireTap during this app session. They reset when you switch accounts or close the project.")
        }
    }

    private var thresholdsSection: some View {
        Section {
            thresholdRow(
                label: "Large read warning",
                value: usage.firestoreReads,
                threshold: usage.largeReadThreshold,
                symbol: "doc.text.magnifyingglass"
            )
            thresholdRow(
                label: "Heavy session reads",
                value: usage.firestoreReads,
                threshold: usage.largeReadThreshold * 2,
                symbol: "exclamationmark.triangle"
            )
        } header: {
            Text("Warnings")
        } footer: {
            Text("Warnings are local heuristics only. They do not reflect Google Cloud billing or quota enforcement.")
        }
    }

    private var billingSection: some View {
        Section {
            ContentUnavailableView {
                Label("Live billing unavailable", systemImage: "creditcard.trianglebadge.exclamationmark")
            } description: {
                Text("Cloud Billing budgets and spend require the Cloud Billing Budget API plus BigQuery billing export with billing account access scopes FireTap does not request at sign-in. Session counters above are the only live cost signal in this build.")
            }
            .listRowBackground(Theme.Palette.surface)
        } header: {
            Text("Cloud billing")
        }
    }

    @ViewBuilder
    private func thresholdRow(label: String, value: Int, threshold: Int, symbol: String) -> some View {
        let exceeded = value >= threshold
        HStack {
            Label(label, systemImage: symbol)
                .foregroundStyle(exceeded ? Theme.Palette.warning : Theme.Palette.textPrimary)
            Spacer()
            if exceeded {
                StatusChip(
                    text: "\(value) / \(threshold)",
                    systemImage: "exclamationmark.triangle.fill",
                    color: Theme.Palette.warning,
                    container: Theme.Palette.warningContainer
                )
            } else {
                Text("\(value) / \(threshold)")
                    .font(.pcCaption)
                    .foregroundStyle(Theme.Palette.textSecondary)
            }
        }
        .listRowBackground(Theme.Palette.surface)
    }
}
