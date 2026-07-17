import SwiftUI

/// Folder-scoped, paginated object listing for a bucket. Folders (common
/// prefixes) push a new scope; files open a read-only metadata detail. Never
/// downloads large files automatically — downloads are an explicit, gated
/// action.
struct StorageObjectListView: View {
    let bucket: String
    let prefix: String
    let title: String

    @Environment(AppEnvironment.self) private var env
    @State private var model: StorageObjectListViewModel?

    var body: some View {
        Group {
            if let model {
                content(model)
            } else {
                LoadingStateView().padding()
            }
        }
        .appBackground()
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if model == nil {
                let vm = StorageObjectListViewModel(bucket: bucket, prefix: prefix, service: env.storageService)
                model = vm
                await vm.loadFirstPage()
            }
        }
    }

    @ViewBuilder
    private func content(_ model: StorageObjectListViewModel) -> some View {
        if let error = model.error {
            ErrorStateView(error: error) { Task { await model.loadFirstPage() } }
        } else if model.isEmpty {
            EmptyStateView(
                title: "Empty",
                message: "No folders or files here.",
                systemImage: "folder"
            )
        } else {
            List {
                if !model.folders.isEmpty {
                    Section("Folders • \(model.folders.count)") {
                        ForEach(model.folders, id: \.self) { folder in
                            NavigationLink {
                                StorageObjectListView(
                                    bucket: bucket,
                                    prefix: folder,
                                    title: folderName(folder)
                                )
                            } label: {
                                Label(folderName(folder), systemImage: "folder.fill")
                                    .foregroundStyle(Theme.Palette.textPrimary)
                            }
                            .listRowBackground(Theme.Palette.surface)
                        }
                    }
                }

                Section("Files • \(model.objects.count)") {
                    if model.objects.isEmpty {
                        Text("No files at this level.")
                            .foregroundStyle(Theme.Palette.textSecondary)
                            .listRowBackground(Theme.Palette.surface)
                    }
                    ForEach(model.objects) { object in
                        NavigationLink {
                            StorageObjectDetailView(object: object)
                        } label: {
                            fileRow(object)
                        }
                        .listRowBackground(Theme.Palette.surface)
                    }
                    paginationRow(model)
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .refreshable { await model.loadFirstPage() }
        }
    }

    @ViewBuilder
    private func paginationRow(_ model: StorageObjectListViewModel) -> some View {
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
        }
    }

    private func fileRow(_ object: StorageObject) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(object.displayName(strippingPrefix: prefix))
                .foregroundStyle(Theme.Palette.textPrimary)
                .lineLimit(1)
            HStack(spacing: 6) {
                Text(StorageFormat.size(object.byteCount))
                    .font(.pcCaption).foregroundStyle(Theme.Palette.textSecondary)
                if let type = object.contentType {
                    Text("• \(type)").font(.pcCaption).foregroundStyle(Theme.Palette.textTertiary).lineLimit(1)
                }
            }
        }
    }

    private func folderName(_ prefix: String) -> String {
        let parts = prefix.split(separator: "/", omittingEmptySubsequences: true)
        return parts.last.map(String.init) ?? prefix
    }
}
