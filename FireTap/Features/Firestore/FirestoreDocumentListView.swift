import SwiftUI

/// Paginated document list with an explicit, honest cost preview: page size,
/// documents returned, and reads caused this session — plus a warning before
/// unusually large reads.
struct FirestoreDocumentListView: View {
    let project: FirebaseProject
    let databaseID: String
    let collectionPath: String
    let title: String

    @Environment(AppEnvironment.self) private var env
    @State private var model: FirestoreDocumentListViewModel?

    var body: some View {
        Group {
            if let model {
                content(model)
            } else {
                costPreviewPlaceholder
            }
        }
        .appBackground()
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if model == nil {
                model = FirestoreDocumentListViewModel(
                    projectID: project.projectId,
                    databaseID: databaseID,
                    collectionPath: collectionPath,
                    service: env.firestoreService,
                    usage: env.sessionUsage
                )
            }
        }
    }

    @ViewBuilder
    private func content(_ model: FirestoreDocumentListViewModel) -> some View {
        @Bindable var model = model
        List {
            Section {
                costPreview(model)
            } header: {
                Text("Before you query")
            }

            if let error = model.error {
                Section {
                    ErrorStateView(error: error) {
                        Task { await model.loadFirstPage() }
                    }
                    .listRowBackground(Color.clear)
                }
            }

            if model.hasLoadedOnce {
                Section("Documents • \(model.documents.count)") {
                    if model.documents.isEmpty {
                        Text("No documents returned.")
                            .foregroundStyle(Theme.Palette.textSecondary)
                            .listRowBackground(Theme.Palette.surface)
                    }
                    ForEach(model.documents) { doc in
                        NavigationLink {
                            FirestoreDocumentDetailView(project: project, document: doc)
                        } label: {
                            documentRow(doc)
                        }
                        .listRowBackground(Theme.Palette.surface)
                    }
                    if !model.reachedEnd {
                        Button {
                            Task { await model.loadNextPage() }
                        } label: {
                            HStack {
                                if model.isLoading { ProgressView() }
                                Text(model.isLoading ? "Loading…" : "Load next \(model.pageSize)")
                            }
                        }
                        .disabled(model.isLoading)
                        .listRowBackground(Theme.Palette.surface)
                    } else {
                        Text("End of collection reached.")
                            .font(.pcCaption)
                            .foregroundStyle(Theme.Palette.textTertiary)
                            .listRowBackground(Theme.Palette.surface)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
    }

    private func costPreview(_ model: FirestoreDocumentListViewModel) -> some View {
        @Bindable var model = model
        return VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Stepper(value: $model.pageSize, in: 5...500, step: 5) {
                HStack {
                    Text("Page size")
                    Spacer()
                    Text("\(model.pageSize)").foregroundStyle(Theme.Palette.textSecondary)
                }
            }
            .disabled(model.hasLoadedOnce)

            metricRow("Documents returned", value: model.hasLoadedOnce ? "\(model.documents.count)" : "—")
            metricRow("Reads this session", value: "\(model.sessionReads)")

            if model.willBeLargeRead {
                Label("This page size will read \(model.pageSize) documents at once, which can be costly. Consider a smaller page.",
                      systemImage: "exclamationmark.triangle.fill")
                    .font(.pcCaption)
                    .foregroundStyle(Theme.Palette.warning)
            }

            if !model.hasLoadedOnce {
                Button {
                    Task { await model.loadFirstPage() }
                } label: {
                    Text(model.isLoading ? "Loading…" : "Load \(model.pageSize) documents")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Theme.Palette.accent, in: RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous))
                        .foregroundStyle(.white)
                }
                .disabled(model.isLoading)
            }
        }
        .listRowBackground(Theme.Palette.surface)
    }

    private func metricRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(Theme.Palette.textSecondary)
            Spacer()
            Text(value).font(.pcBodyEmphasis).foregroundStyle(Theme.Palette.textPrimary)
        }
    }

    private func documentRow(_ doc: FirestoreDocument) -> some View {
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

    private var costPreviewPlaceholder: some View {
        LoadingStateView().padding()
    }
}
