import SwiftUI

/// Creates a Firestore document with optional custom ID and initial fields.
struct FirestoreCreateDocumentView: View {
    let project: FirebaseProject
    let databaseID: String
    let collectionPath: String
    let onCreated: (FirestoreDocument) -> Void

    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss
    @State private var model: FirestoreCreateDocumentViewModel?

    var body: some View {
        NavigationStack {
            Group {
                if let model {
                    form(model)
                } else {
                    LoadingStateView().padding()
                }
            }
            .appBackground()
            .navigationTitle("Create document")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .task {
                if model == nil {
                    model = FirestoreCreateDocumentViewModel(
                        projectID: project.projectId,
                        databaseID: databaseID,
                        collectionPath: collectionPath,
                        service: env.firestoreService,
                        usage: env.sessionUsage,
                        audit: env.audit
                    )
                }
            }
        }
    }

    @ViewBuilder
    private func form(_ model: FirestoreCreateDocumentViewModel) -> some View {
        @Bindable var model = model
        Form {
            if env.selectedProjectEnvironment.isProduction {
                Section {
                    Label("Production project", systemImage: "exclamationmark.shield.fill")
                        .foregroundStyle(Theme.Palette.danger)
                }
            }

            if let gate = WriteGate.message(env: env) {
                Section {
                    CardUnavailableNote(message: gate.text, systemImage: gate.symbol)
                    if env.featureGate.canOfferWrites && !env.safeMode.isWriteUnlocked {
                        Button("Unlock with \(env.safeMode.biometryName)") {
                            Task { _ = await env.safeMode.requestWriteUnlock(reason: "Create Firestore document") }
                        }
                    }
                }
            }

            Section {
                TextField("Optional document ID", text: $model.documentID)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.pcMono)
                Text("Leave empty to let Firestore assign an auto ID.")
                    .font(.pcCaption)
                    .foregroundStyle(Theme.Palette.textTertiary)
            } header: {
                Text("Document ID")
            } footer: {
                Text("Collection: \(collectionPath)")
            }

            Section {
                Picker("Input format", selection: $model.inputMode) {
                    ForEach(FirestoreCreateDocumentViewModel.InputMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)

                TextEditor(text: $model.fieldsText)
                    .font(.pcMonoSmall)
                    .frame(minHeight: 160)
                    .accessibilityLabel("Initial fields")

                if model.inputMode == .simple {
                    Text("One field per line: key: value. Values infer bool, number, or string.")
                        .font(.pcCaption)
                        .foregroundStyle(Theme.Palette.textTertiary)
                } else {
                    Text("JSON object with plain values, e.g. {\"name\":\"Ada\",\"active\":true}.")
                        .font(.pcCaption)
                        .foregroundStyle(Theme.Palette.textTertiary)
                }

                if let parseError = model.parseError {
                    Text(parseError)
                        .font(.pcCaption)
                        .foregroundStyle(Theme.Palette.danger)
                }
            } header: {
                Text("Initial fields")
            }

            if let error = model.error {
                Section {
                    Text(error.userMessage)
                        .foregroundStyle(Theme.Palette.danger)
                }
            }

            Section {
                Button {
                    Task { await submit(model) }
                } label: {
                    HStack {
                        Spacer()
                        if model.isCreating {
                            ProgressView()
                        } else {
                            Text("Create document")
                        }
                        Spacer()
                    }
                }
                .disabled(model.isCreating || WriteGate.message(env: env) != nil)
            }
        }
        .scrollContentBackground(.hidden)
    }

    private func submit(_ model: FirestoreCreateDocumentViewModel) async {
        guard await WriteGate.ensureUnlocked(env: env, reason: "Create Firestore document") else { return }
        guard let created = await model.create() else { return }
        onCreated(created)
        dismiss()
    }
}
