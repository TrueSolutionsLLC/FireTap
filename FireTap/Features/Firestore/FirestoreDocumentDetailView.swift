import SwiftUI
import UIKit

/// Read-only document detail with a field tree, a raw JSON view, timestamps,
/// and copy actions. Write actions are surfaced only when permitted (Pro + Safe
/// Mode unlocked); otherwise an honest gate is shown instead of a dead button.
struct FirestoreDocumentDetailView: View {
    let project: FirebaseProject
    let document: FirestoreDocument
    @Environment(AppEnvironment.self) private var env

    enum ViewMode: String, CaseIterable { case fields = "Fields", json = "JSON" }
    @State private var mode: ViewMode = .fields

    var body: some View {
        List {
            Section {
                Picker("View", selection: $mode) {
                    ForEach(ViewMode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
            }

            switch mode {
            case .fields:
                fieldsSection
            case .json:
                jsonSection
            }

            metadataSection
            writeSection
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .appBackground()
        .navigationTitle(document.documentID)
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private var fieldsSection: some View {
        Section("Fields • \(document.fields?.count ?? 0)") {
            if let fields = document.fields, !fields.isEmpty {
                ForEach(fields.keys.sorted(), id: \.self) { key in
                    if let value = fields[key] {
                        FirestoreFieldRow(name: key, value: value, depth: 0)
                    }
                }
            } else {
                Text("This document has no fields.")
                    .foregroundStyle(Theme.Palette.textSecondary)
            }
        }
        .listRowBackground(Theme.Palette.surface)
    }

    @ViewBuilder
    private var jsonSection: some View {
        Section("JSON") {
            Text(prettyJSON)
                .font(.pcMonoSmall)
                .foregroundStyle(Theme.Palette.textPrimary)
                .textSelection(.enabled)
            Button {
                UIPasteboard.general.string = prettyJSON
            } label: {
                Label("Copy JSON", systemImage: "doc.on.doc")
            }
        }
        .listRowBackground(Theme.Palette.surface)
    }

    private var metadataSection: some View {
        Section("Metadata") {
            metaRow("Path", document.relativePath)
            if let create = document.createTime { metaRow("Created", create) }
            if let update = document.updateTime { metaRow("Updated", update) }
            Button {
                UIPasteboard.general.string = document.relativePath
            } label: {
                Label("Copy document path", systemImage: "doc.on.doc")
            }
            Button {
                UIPasteboard.general.string = document.name
            } label: {
                Label("Copy full reference", systemImage: "link")
            }
        }
        .listRowBackground(Theme.Palette.surface)
    }

    @ViewBuilder
    private var writeSection: some View {
        Section {
            if env.selectedProjectEnvironment.isProduction {
                CardUnavailableNote(
                    message: "This is a production project. Editing requires unlocking write access with \(env.safeMode.biometryName) each session.",
                    systemImage: "lock.shield"
                )
            } else if !env.featureGate.canOfferWrites {
                CardUnavailableNote(
                    message: "Editing documents is a Pro feature. Free access is read-only.",
                    systemImage: "star.circle"
                )
            } else {
                CardUnavailableNote(
                    message: "Editing uses guarded writes with update-time preconditions. Enable it from the collection toolbar.",
                    systemImage: "square.and.pencil"
                )
            }
        } header: {
            Text("Editing")
        }
        .listRowBackground(Theme.Palette.surface)
    }

    private func metaRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(label).foregroundStyle(Theme.Palette.textSecondary)
            Spacer()
            Text(value)
                .font(.pcMonoSmall)
                .foregroundStyle(Theme.Palette.textPrimary)
                .multilineTextAlignment(.trailing)
                .textSelection(.enabled)
        }
    }

    private var prettyJSON: String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        guard let fields = document.fields,
              let data = try? encoder.encode(fields),
              let string = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return string
    }
}

/// One field row that recursively renders nested maps and arrays.
struct FirestoreFieldRow: View {
    let name: String
    let value: FirestoreValue
    let depth: Int

    var body: some View {
        switch value {
        case .map(let fields):
            DisclosureGroup {
                ForEach(fields.keys.sorted(), id: \.self) { key in
                    if let child = fields[key] {
                        FirestoreFieldRow(name: key, value: child, depth: depth + 1)
                    }
                }
            } label: {
                labelRow(typeBadge: "map")
            }
        case .array(let values):
            DisclosureGroup {
                ForEach(Array(values.enumerated()), id: \.offset) { index, child in
                    FirestoreFieldRow(name: "[\(index)]", value: child, depth: depth + 1)
                }
            } label: {
                labelRow(typeBadge: "array")
            }
        default:
            HStack {
                Text(name).foregroundStyle(Theme.Palette.textPrimary)
                Spacer()
                Text(value.displayString)
                    .font(.pcMonoSmall)
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.trailing)
                typeTag(value.typeName)
            }
        }
    }

    private func labelRow(typeBadge: String) -> some View {
        HStack {
            Text(name).foregroundStyle(Theme.Palette.textPrimary)
            Spacer()
            typeTag(typeBadge)
        }
    }

    private func typeTag(_ text: String) -> some View {
        Text(text)
            .font(.system(.caption2, design: .monospaced))
            .foregroundStyle(Theme.Palette.textTertiary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Theme.Palette.surfaceRaised, in: Capsule())
    }
}
