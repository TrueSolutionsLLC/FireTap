import SwiftUI
import UniformTypeIdentifiers

/// Folder-scoped, paginated object listing for a bucket. Folders (common
/// prefixes) push a new scope; files open metadata detail with explicit actions.
struct StorageObjectListView: View {
    let projectID: String
    let bucket: String
    let prefix: String
    let title: String

    @Environment(AppEnvironment.self) private var env
    @State private var model: StorageObjectListViewModel?
    @State private var showFileImporter = false
    @State private var uploadStatus: String?
    @State private var uploading = false

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
        .toolbar {
            if WriteGate.message(env: env) == nil {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showFileImporter = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .accessibilityLabel("Upload file")
                    .disabled(uploading)
                }
            }
        }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.data, .item, .content, .image, .pdf, .json, .plainText],
            allowsMultipleSelection: false
        ) { result in
            Task { await handleUploadSelection(result) }
        }
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
        } else if model.isEmpty && uploadStatus == nil {
            EmptyStateView(
                title: "Empty",
                message: "No folders or files here.",
                systemImage: "folder"
            )
        } else {
            List {
                if let uploadStatus {
                    Section {
                        Text(uploadStatus)
                            .font(.pcCaption)
                            .foregroundStyle(Theme.Palette.textSecondary)
                    }
                    .listRowBackground(Theme.Palette.surface)
                }

                if !model.folders.isEmpty {
                    Section("Folders • \(model.folders.count)") {
                        ForEach(model.folders, id: \.self) { folder in
                            NavigationLink {
                                StorageObjectListView(
                                    projectID: projectID,
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
                            StorageObjectDetailView(projectID: projectID, object: object)
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

    private func handleUploadSelection(_ result: Result<[URL], Error>) async {
        guard await WriteGate.ensureUnlocked(env: env, reason: "Upload Cloud Storage object") else { return }
        uploading = true
        defer { uploading = false }
        switch result {
        case .failure:
            uploadStatus = "File selection cancelled."
        case .success(let urls):
            guard let sourceURL = urls.first else {
                uploadStatus = "No file selected."
                return
            }
            let accessed = sourceURL.startAccessingSecurityScopedResource()
            defer {
                if accessed { sourceURL.stopAccessingSecurityScopedResource() }
            }
            do {
                let data = try Data(contentsOf: sourceURL)
                if data.count > LiveStorageService.absoluteMaxUploadBytes {
                    uploadStatus = "File exceeds \(StorageFormat.size(Int64(LiveStorageService.absoluteMaxUploadBytes))) upload limit."
                    return
                }
                let fileName = sourceURL.lastPathComponent
                let objectName = prefix + fileName
                let contentType = UTType(filenameExtension: sourceURL.pathExtension)?.preferredMIMEType
                _ = try await env.storageService.uploadObject(
                    bucket: bucket,
                    name: objectName,
                    contentType: contentType,
                    data: data
                )
                uploadStatus = "Uploaded \(fileName) to \(objectName)."
                await env.audit.record(AuditEntry(
                    accountID: env.accountManager.activeAccountID,
                    projectID: projectID,
                    action: "storage.upload",
                    resource: objectName,
                    summary: "Uploaded storage object",
                    reversible: false
                ))
                await model?.loadFirstPage()
            } catch let error as APIError {
                uploadStatus = error.userMessage
            } catch {
                uploadStatus = "Upload failed."
            }
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
