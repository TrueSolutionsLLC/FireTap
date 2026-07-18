import SwiftUI

/// Structured query builder with saved queries, explicit limits, and honest counts.
struct FirestoreQueryBuilderView: View {
    let project: FirebaseProject
    let databaseID: String
    let collectionPath: String
    var initialSavedQueryID: String?

    @Environment(AppEnvironment.self) private var env
    @State private var model: FirestoreQueryBuilderViewModel?
    @State private var saveTitle = ""
    @State private var showSavePrompt = false
    @State private var saveConfirmation: String?

    private var accountID: String { env.accountManager.activeAccountID ?? "anonymous" }

    var body: some View {
        Group {
            if let model {
                content(model)
            } else {
                LoadingStateView().padding()
            }
        }
        .appBackground()
        .navigationTitle("Run query")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if model == nil {
                let context = FirestoreFieldsParser.collectionContext(for: collectionPath)
                model = FirestoreQueryBuilderViewModel(
                    projectID: project.projectId,
                    databaseID: databaseID,
                    collectionContext: context,
                    service: env.firestoreService,
                    usage: env.sessionUsage
                )
                if let initialSavedQueryID,
                   let saved = env.savedQueries
                    .queries(account: accountID, projectID: project.projectId)
                    .first(where: { $0.id == initialSavedQueryID }) {
                    model?.applySaved(saved)
                }
            }
        }
        .alert("Save query", isPresented: $showSavePrompt) {
            TextField("Title", text: $saveTitle)
            Button("Cancel", role: .cancel) {
                saveTitle = ""
            }
            Button("Save") {
                saveCurrentQuery()
            }
            .disabled(saveTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        } message: {
            Text("Saved queries are stored locally for this account and project.")
        }
    }

    @ViewBuilder
    private func content(_ model: FirestoreQueryBuilderViewModel) -> some View {
        @Bindable var model = model
        List {
            Section {
                LabeledContent("Collection ID") {
                    Text(model.collectionID)
                        .font(.pcMono)
                        .foregroundStyle(Theme.Palette.textSecondary)
                }
                if let parent = model.parentDocumentPath {
                    LabeledContent("Parent document") {
                        Text(parent)
                            .font(.pcMonoSmall)
                            .foregroundStyle(Theme.Palette.textSecondary)
                            .multilineTextAlignment(.trailing)
                    }
                }
            } header: {
                Text("Target")
            }

            Section {
                TextField("Field path", text: $model.filterField)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.pcMono)
                Picker("Operator", selection: $model.filterOp) {
                    ForEach(FirestoreQueryOperator.allCases) { op in
                        Text(op.label).tag(op)
                    }
                }
                Picker("Value type", selection: $model.filterValueKind) {
                    ForEach(SavedQueryFilterValueKind.allCases) { kind in
                        Text(kind.label).tag(kind)
                    }
                }
                .onChange(of: model.filterValueKind) { _, kind in
                    if kind == .bool, model.filterValue.isEmpty {
                        model.filterValue = "true"
                    }
                }
                switch model.filterValueKind {
                case .bool:
                    Picker("Value", selection: $model.filterValue) {
                        Text("true").tag("true")
                        Text("false").tag("false")
                    }
                    .pickerStyle(.segmented)
                default:
                    TextField(model.filterValueKind == .number ? "Number value" : "String value", text: $model.filterValue)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.pcMono)
                        .keyboardType(model.filterValueKind == .number ? .decimalPad : .default)
                }
            } header: {
                Text("Optional filter")
            } footer: {
                Text("Leave the field empty to query the whole collection.")
            }

            Section {
                TextField("Order by field", text: $model.orderField)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.pcMono)
                Toggle("Descending", isOn: $model.descending)
                    .disabled(model.orderField.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            } header: {
                Text("Optional order")
            } footer: {
                Text("Leave empty to use Firestore's default document order.")
            }

            Section {
                Stepper(value: $model.limit, in: 1...500, step: 1) {
                    HStack {
                        Text("Limit")
                        Spacer()
                        Text("\(model.limit)").foregroundStyle(Theme.Palette.textSecondary)
                    }
                }
                metricRow("Reads this session", value: "\(model.sessionReads)")
            } header: {
                Text("Page size")
            } footer: {
                Text("Document counts are API page sizes, not guaranteed billed reads.")
            }

            savedQueriesSection(model)

            Section {
                Button {
                    Task { await model.runQuery() }
                } label: {
                    HStack {
                        Spacer()
                        if model.isRunning {
                            ProgressView()
                        } else {
                            Text("Run query")
                        }
                        Spacer()
                    }
                }
                .disabled(model.isRunning)

                Button("Save query…") {
                    saveTitle = defaultSaveTitle(model)
                    showSavePrompt = true
                }
                .disabled(model.isRunning)
            }

            if let error = model.error {
                Section {
                    ErrorStateView(error: error) {
                        Task { await model.runQuery() }
                    }
                    .listRowBackground(Color.clear)
                }
            }

            if model.hasRunOnce {
                Section("Results • \(model.results.count)") {
                    metricRow("Requested", value: "\(model.lastRequestedCount)")
                    metricRow("Returned", value: "\(model.results.count)")

                    if model.results.isEmpty {
                        Text("No documents matched this query.")
                            .foregroundStyle(Theme.Palette.textSecondary)
                    } else {
                        ForEach(model.results) { doc in
                            NavigationLink {
                                FirestoreDocumentDetailView(
                                    project: project,
                                    databaseID: databaseID,
                                    document: doc
                                )
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(doc.documentID)
                                        .font(.pcMono)
                                        .foregroundStyle(Theme.Palette.textPrimary)
                                        .lineLimit(1)
                                    Text("\(doc.fields?.count ?? 0) fields")
                                        .font(.pcMonoSmall)
                                        .foregroundStyle(Theme.Palette.textSecondary)
                                }
                            }
                        }
                    }
                }
            }

            if let saveConfirmation {
                Section {
                    Text(saveConfirmation)
                        .font(.pcCaption)
                        .foregroundStyle(Theme.Palette.healthy)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
    }

    @ViewBuilder
    private func savedQueriesSection(_ model: FirestoreQueryBuilderViewModel) -> some View {
        let saved = env.savedQueries
            .queries(account: accountID, projectID: project.projectId)
            .filter { $0.collectionID == model.collectionID }

        Section("Saved queries • \(saved.count)") {
            if saved.isEmpty {
                Text("No saved queries for this collection.")
                    .foregroundStyle(Theme.Palette.textSecondary)
            } else {
                ForEach(saved) { query in
                    Button {
                        model.applySaved(query)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(query.title)
                                .font(.pcBodyEmphasis)
                                .foregroundStyle(Theme.Palette.textPrimary)
                            Text(savedQuerySubtitle(query))
                                .font(.pcCaption)
                                .foregroundStyle(Theme.Palette.textSecondary)
                        }
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            env.savedQueries.delete(id: query.id, account: accountID, projectID: project.projectId)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .listRowBackground(Theme.Palette.surface)
    }

    private func saveCurrentQuery() {
        guard let model else { return }
        let title = saveTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        let saved = model.makeSavedQuery(title: title)
        env.savedQueries.save(saved, account: accountID, projectID: project.projectId)
        saveTitle = ""
        saveConfirmation = "Saved \"\(saved.title)\"."
    }

    private func defaultSaveTitle(_ model: FirestoreQueryBuilderViewModel) -> String {
        if model.filterEnabled {
            return "\(model.collectionID) where \(model.filterField.trimmingCharacters(in: .whitespacesAndNewlines))"
        }
        return "\(model.collectionID) • limit \(model.limit)"
    }

    private func savedQuerySubtitle(_ query: SavedFirestoreQuery) -> String {
        var parts: [String] = ["limit \(query.limit)"]
        if let orderField = query.orderField, !orderField.isEmpty {
            parts.insert("order \(orderField) \(query.descending ? "desc" : "asc")", at: 0)
        }
        if let field = query.fieldPath, let value = query.stringValue, !field.isEmpty {
            let opLabel = FirestoreQueryOperator(rawValue: query.op ?? "")?.label ?? "=="
            parts.insert("\(field) \(opLabel) \(value)", at: 0)
        }
        return parts.joined(separator: " • ")
    }

    private func metricRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(Theme.Palette.textSecondary)
            Spacer()
            Text(value).font(.pcBodyEmphasis).foregroundStyle(Theme.Palette.textPrimary)
        }
        .listRowBackground(Theme.Palette.surface)
    }
}
