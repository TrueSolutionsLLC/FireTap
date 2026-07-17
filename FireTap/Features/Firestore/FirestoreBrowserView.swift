import SwiftUI

/// Live Firestore browser (Figma "04 — Firestore"). Lists real collections for
/// the project's default database and navigates into paginated, read-counted
/// document lists.
struct FirestoreBrowserView: View {
    let project: FirebaseProject
    @Environment(AppEnvironment.self) private var env
    @State private var model: FirestoreBrowserViewModel?

    var body: some View {
        Group {
            if let model {
                content(model)
            } else {
                LoadingStateView().padding()
            }
        }
        .appBackground()
        .navigationTitle("Firestore")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if model == nil {
                let vm = FirestoreBrowserViewModel(projectID: project.projectId, service: env.firestoreService)
                model = vm
                await vm.load()
            }
        }
    }

    @ViewBuilder
    private func content(_ model: FirestoreBrowserViewModel) -> some View {
        @Bindable var model = model
        switch model.phase {
        case .idle, .loading:
            LoadingStateView().padding()
        case .failed(let error):
            ErrorStateView(error: error) { Task { await model.load() } }
        case .loaded(let ids):
            if ids.isEmpty {
                EmptyStateView(
                    title: "No collections",
                    message: "This database has no top-level collections, or your account can't read them.",
                    systemImage: "tablecells"
                )
            } else {
                List {
                    if env.selectedProjectEnvironment.isProduction {
                        Section {
                            HStack {
                                Label("Production Safe Mode", systemImage: "lock.shield")
                                    .foregroundStyle(Theme.Palette.healthy)
                                Spacer()
                                Text("Read only").font(.pcCaption).foregroundStyle(Theme.Palette.textSecondary)
                            }
                            .listRowBackground(Theme.Palette.healthyContainer.opacity(0.4))
                        }
                    }
                    Section("Collections • \(model.displayedCollections.count)") {
                        ForEach(model.displayedCollections, id: \.self) { collection in
                            NavigationLink {
                                FirestoreDocumentListView(
                                    project: project,
                                    databaseID: model.databaseID,
                                    collectionPath: collection,
                                    title: collection
                                )
                            } label: {
                                Label(collection, systemImage: "tablecells")
                                    .foregroundStyle(Theme.Palette.textPrimary)
                            }
                            .listRowBackground(Theme.Palette.surface)
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .searchable(text: $model.searchText, prompt: "Search collections")
                .refreshable { await model.load() }
            }
        }
    }
}
