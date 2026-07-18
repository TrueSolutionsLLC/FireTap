import SwiftUI
import UIKit

/// Document detail with field/JSON views, copy actions, guarded edit/delete,
/// update-time conflict handling, and before/after previews.
struct FirestoreDocumentDetailView: View {
    let project: FirebaseProject
    let databaseID: String
    let document: FirestoreDocument

    @Environment(AppEnvironment.self) private var env
    @State private var editor: FirestoreDocumentEditorViewModel?
    @State private var mode: ViewMode = .fields
    @State private var showDeleteConfirm = false
    @State private var showSavePreview = false
    @State private var didDelete = false
    @State private var subcollectionPhase: AsyncPhase<[String]> = .idle
    @Environment(\.dismiss) private var dismiss

    enum ViewMode: String, CaseIterable { case fields = "Fields", json = "JSON", edit = "Edit" }

    private var accountID: String { env.accountManager.activeAccountID ?? "anonymous" }
    private var resourceKey: String { ResourceKey.firestoreDocument(path: document.relativePath) }
    private var isFavorite: Bool { env.preferences.isFavorite(resourceKey, account: accountID) }

    var body: some View {
        Group {
            if let editor {
                content(editor)
            } else {
                LoadingStateView().padding()
            }
        }
        .appBackground()
        .navigationTitle(document.documentID)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { favoriteToolbar }
        .task {
            if editor == nil {
                editor = FirestoreDocumentEditorViewModel(
                    projectID: project.projectId,
                    databaseID: databaseID,
                    document: document,
                    service: env.firestoreService,
                    audit: env.audit
                )
            }
            env.preferences.recordRecentlyViewed(resourceKey, account: accountID)
            await loadSubcollections()
        }
        .onChange(of: didDelete) { _, deleted in
            if deleted { dismiss() }
        }
    }

    @ViewBuilder
    private func content(_ editor: FirestoreDocumentEditorViewModel) -> some View {
        @Bindable var editor = editor
        List {
            Section {
                Picker("View", selection: $mode) {
                    ForEach(ViewMode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
            }

            if let error = editor.error {
                Section {
                    Text(error.userMessage)
                        .foregroundStyle(Theme.Palette.danger)
                    if editor.conflictDetected {
                        Button("Reload document") {
                            Task { await editor.reload() }
                        }
                    }
                }
                .listRowBackground(Theme.Palette.surface)
            }

            switch mode {
            case .fields:
                fieldsSection(editor.document)
            case .json:
                jsonSection(editor.document)
            case .edit:
                editSection(editor)
            }

            subcollectionsSection
            metadataSection(editor.document)
            writeSection(editor)
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .sheet(isPresented: $showDeleteConfirm) {
            TypedConfirmationSheet(
                title: "Delete document",
                message: "This permanently deletes \(editor.document.relativePath) in project \(project.projectId).",
                confirmPhrase: editor.document.documentID,
                confirmButtonTitle: "Delete",
                isProduction: env.selectedProjectEnvironment.isProduction
            ) {
                Task {
                    guard await WriteGate.ensureUnlocked(env: env, reason: "Delete Firestore document") else { return }
                    if await editor.delete() { didDelete = true }
                }
            } onCancel: {}
        }
        .sheet(isPresented: $showSavePreview) {
            NavigationStack {
                List {
                    Section("Before / after") {
                        Text(editor.beforeAfterSummary)
                            .font(.pcMonoSmall)
                            .textSelection(.enabled)
                    }
                    Section {
                        Text("Uses an update-time precondition so concurrent edits fail instead of silently overwriting. Actual Firebase billing may differ from local session counts.")
                            .font(.pcCaption)
                            .foregroundStyle(Theme.Palette.textSecondary)
                    }
                }
                .navigationTitle("Confirm save")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { showSavePreview = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            showSavePreview = false
                            Task {
                                guard await WriteGate.ensureUnlocked(env: env, reason: "Save Firestore document") else { return }
                                _ = await editor.save()
                            }
                        }
                        .disabled(!editor.hasChanges || editor.isSaving)
                    }
                }
            }
            .presentationDetents([.medium, .large])
        }
    }

    @ViewBuilder
    private func fieldsSection(_ document: FirestoreDocument) -> some View {
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
    private func jsonSection(_ document: FirestoreDocument) -> some View {
        let json = prettyJSON(document)
        Section("JSON") {
            Text(json)
                .font(.pcMonoSmall)
                .foregroundStyle(Theme.Palette.textPrimary)
                .textSelection(.enabled)
            Button {
                UIPasteboard.general.string = json
            } label: {
                Label("Copy JSON", systemImage: "doc.on.doc")
            }
        }
        .listRowBackground(Theme.Palette.surface)
    }

    @ViewBuilder
    private func editSection(_ editor: FirestoreDocumentEditorViewModel) -> some View {
        @Bindable var editor = editor
        if let gate = WriteGate.message(env: env) {
            Section {
                CardUnavailableNote(message: gate.text, systemImage: gate.symbol)
                if env.featureGate.canOfferWrites && !env.safeMode.isWriteUnlocked {
                    Button("Unlock with \(env.safeMode.biometryName)") {
                        Task { _ = await env.safeMode.requestWriteUnlock(reason: "Edit Firestore document") }
                    }
                }
            }
            .listRowBackground(Theme.Palette.surface)
        }

        Section("Fields") {
            ForEach(editor.draftFields.keys.sorted(), id: \.self) { key in
                HStack {
                    VStack(alignment: .leading) {
                        Text(key).font(.pcBodyEmphasis)
                        Text(editor.draftFields[key]?.displayString ?? "")
                            .font(.pcMonoSmall)
                            .foregroundStyle(Theme.Palette.textSecondary)
                            .lineLimit(2)
                    }
                    Spacer()
                    Button(role: .destructive) {
                        editor.removeField(key)
                    } label: {
                        Image(systemName: "minus.circle.fill")
                    }
                    .accessibilityLabel("Remove field \(key)")
                }
            }
            TextField("New field name", text: $editor.newFieldName)
            TextField("String value", text: $editor.newFieldStringValue)
            Button("Add string field") { editor.addStringField() }
                .disabled(editor.newFieldName.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .listRowBackground(Theme.Palette.surface)
        .disabled(WriteGate.message(env: env) != nil)

        Section {
            Button {
                showSavePreview = true
            } label: {
                if editor.isSaving { ProgressView() } else { Text("Review & save changes") }
            }
            .disabled(!editor.hasChanges || editor.isSaving || WriteGate.message(env: env) != nil)
        }
        .listRowBackground(Theme.Palette.surface)
    }

    @ToolbarContentBuilder
    private var favoriteToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                env.preferences.setFavorite(!isFavorite, resourceKey: resourceKey, account: accountID)
            } label: {
                Image(systemName: isFavorite ? "star.fill" : "star")
            }
            .accessibilityLabel(isFavorite ? "Remove from favorites" : "Add to favorites")
        }
    }

    @ViewBuilder
    private var subcollectionsSection: some View {
        Section("Subcollections") {
            switch subcollectionPhase {
            case .idle, .loading:
                ProgressView()
                    .listRowBackground(Theme.Palette.surface)
            case .failed(let error):
                Text(error.userMessage)
                    .font(.pcCaption)
                    .foregroundStyle(Theme.Palette.danger)
                    .listRowBackground(Theme.Palette.surface)
            case .loaded(let collectionIds):
                if collectionIds.isEmpty {
                    Text("No subcollections under this document.")
                        .foregroundStyle(Theme.Palette.textSecondary)
                        .listRowBackground(Theme.Palette.surface)
                }
                ForEach(collectionIds, id: \.self) { collectionId in
                    let subcollectionPath = "\(document.relativePath)/\(collectionId)"
                    NavigationLink {
                        FirestoreDocumentListView(
                            project: project,
                            databaseID: databaseID,
                            collectionPath: subcollectionPath,
                            title: collectionId
                        )
                    } label: {
                        Text(collectionId)
                            .font(.pcBodyEmphasis)
                    }
                    .listRowBackground(Theme.Palette.surface)
                }
            }
        }
    }

    private func loadSubcollections() async {
        if subcollectionPhase.value == nil { subcollectionPhase = .loading }
        do {
            let ids = try await env.firestoreService.listCollectionIds(
                projectID: project.projectId,
                databaseID: databaseID,
                parentDocumentPath: document.relativePath
            )
            subcollectionPhase = .loaded(ids)
        } catch let error as APIError {
            subcollectionPhase = .failed(error)
        } catch {
            subcollectionPhase = .failed(.transport(underlying: "unknown"))
        }
    }

    private func metadataSection(_ document: FirestoreDocument) -> some View {
        Section("Metadata") {
            metaRow("Path", document.relativePath)
            if let create = document.createTime { metaRow("Created", create) }
            if let update = document.updateTime { metaRow("Updated", update) }
            Button { UIPasteboard.general.string = document.relativePath } label: {
                Label("Copy document path", systemImage: "doc.on.doc")
            }
            Button { UIPasteboard.general.string = document.name } label: {
                Label("Copy full reference", systemImage: "link")
            }
            Button { UIPasteboard.general.string = document.documentID } label: {
                Label("Copy document ID", systemImage: "doc.on.doc")
            }
        }
        .listRowBackground(Theme.Palette.surface)
    }

    @ViewBuilder
    private func writeSection(_ editor: FirestoreDocumentEditorViewModel) -> some View {
        Section {
            if let gate = WriteGate.message(env: env) {
                CardUnavailableNote(message: gate.text, systemImage: gate.symbol)
            }
            Button("Delete document…", role: .destructive) {
                showDeleteConfirm = true
            }
            .disabled(WriteGate.message(env: env) != nil || editor.isDeleting)
        } header: {
            Text("Danger zone")
        } footer: {
            Text("Deletes use update-time preconditions. Undo is not offered because a deleted document cannot be restored safely from this client.")
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

    private func prettyJSON(_ document: FirestoreDocument) -> String {
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
            .contextMenu {
                Button {
                    UIPasteboard.general.string = value.displayString
                } label: {
                    Label("Copy value", systemImage: "doc.on.doc")
                }
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
