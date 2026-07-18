import SwiftUI

/// Object metadata with explicit download, upload, rename, and delete actions.
/// Large files never download automatically.
struct StorageObjectDetailView: View {
    let projectID: String
    let object: StorageObject
    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss

    @State private var downloadURL: URL?
    @State private var showDeleteConfirm = false
    @State private var showRenameSheet = false
    @State private var renameDestination = ""
    @State private var statusMessage: String?
    @State private var busy = false
    @State private var downloadProgress: String?

    var body: some View {
        List {
            metadataSection
            actionsSection
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .appBackground()
        .navigationTitle(fileName)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showDeleteConfirm) {
            TypedConfirmationSheet(
                title: "Delete object",
                message: "Permanently delete \(object.name) from bucket \(object.bucket ?? "unknown").",
                confirmPhrase: fileName,
                confirmButtonTitle: "Delete",
                isProduction: env.selectedProjectEnvironment.isProduction
            ) {
                Task { await deleteObject() }
            } onCancel: {}
        }
        .sheet(isPresented: $showRenameSheet) {
            renameSheet
        }
    }

    private var metadataSection: some View {
        Section("Object") {
            copyableRow("Name", object.name, mono: true)
            detailRow("Size", StorageFormat.size(object.byteCount))
            if let type = object.contentType { detailRow("Type", type) }
            if let bucket = object.bucket { detailRow("Bucket", bucket) }
            if let updated = object.updatedDate {
                detailRow("Updated", updated.formatted(date: .abbreviated, time: .shortened))
            }
        }
        .listRowBackground(Theme.Palette.surface)
    }

    private var actionsSection: some View {
        Section {
            if let downloadURL {
                ShareLink(item: downloadURL) {
                    Label("Share downloaded file", systemImage: "square.and.arrow.up")
                }
            }
            Button {
                Task { await downloadObject() }
            } label: {
                if busy && downloadProgress != nil {
                    HStack {
                        ProgressView()
                        Text(downloadProgress ?? "Downloading…")
                    }
                } else {
                    Label("Download to temp file…", systemImage: "arrow.down.circle")
                }
            }
            .disabled(busy)

            if let gate = WriteGate.message(env: env) {
                CardUnavailableNote(message: gate.text, systemImage: gate.symbol)
                if env.featureGate.canOfferWrites && !env.safeMode.isWriteUnlocked {
                    Button("Unlock with \(env.safeMode.biometryName)") {
                        Task { _ = await env.safeMode.requestWriteUnlock(reason: "Manage Cloud Storage objects") }
                    }
                }
            } else {
                Button("Rename (copy + delete)…") {
                    renameDestination = suggestedRename
                    showRenameSheet = true
                }
                .disabled(busy)
                Button("Delete object…", role: .destructive) {
                    showDeleteConfirm = true
                }
                .disabled(busy)
            }

            if let statusMessage {
                Text(statusMessage)
                    .font(.pcCaption)
                    .foregroundStyle(Theme.Palette.textSecondary)
            }
        } header: {
            Text("Actions")
        } footer: {
            Text("Rename uses Cloud Storage copy + delete and is not atomic. Downloads are explicit and saved to a temp file you can share.")
        }
        .listRowBackground(Theme.Palette.surface)
    }

    private var renameSheet: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Renaming copies the object to a new name, then deletes the original. This is not atomic — if delete fails you may have duplicates.")
                        .font(.pcCaption)
                        .foregroundStyle(Theme.Palette.textSecondary)
                }
                Section("New object name") {
                    TextField("Full object path", text: $renameDestination)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.pcMonoSmall)
                }
            }
            .navigationTitle("Rename object")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showRenameSheet = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Rename") {
                        showRenameSheet = false
                        Task { await renameObject() }
                    }
                    .disabled(renameDestination.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || busy)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private var fileName: String {
        object.name.split(separator: "/").last.map(String.init) ?? object.name
    }

    private var suggestedRename: String {
        object.name
    }

    private func downloadObject() async {
        guard let bucket = object.bucket else {
            statusMessage = "Missing bucket name."
            return
        }
        if let bytes = object.byteCount, bytes > 50 * 1_024 * 1_024 {
            statusMessage = "This object is \(StorageFormat.size(bytes)). Download may take a while."
        }
        busy = true
        downloadProgress = "Downloading…"
        defer {
            busy = false
            downloadProgress = nil
        }
        do {
            let result = try await env.storageService.downloadObject(bucket: bucket, name: object.name)
            downloadURL = result.fileURL
            statusMessage = "Downloaded \(StorageFormat.size(result.byteCount)) to a temp file."
        } catch let error as APIError {
            statusMessage = error.userMessage
        } catch {
            statusMessage = "Download failed."
        }
    }

    private func deleteObject() async {
        guard let bucket = object.bucket else {
            statusMessage = "Missing bucket name."
            return
        }
        guard await WriteGate.ensureUnlocked(env: env, reason: "Delete Cloud Storage object") else { return }
        busy = true
        defer { busy = false }
        do {
            try await env.storageService.deleteObject(bucket: bucket, name: object.name)
            await env.audit.record(AuditEntry(
                accountID: env.accountManager.activeAccountID,
                projectID: projectID,
                action: "storage.delete",
                resource: object.name,
                summary: "Deleted storage object",
                reversible: false
            ))
            dismiss()
        } catch let error as APIError {
            statusMessage = error.userMessage
        } catch {
            statusMessage = "Delete failed."
        }
    }

    private func renameObject() async {
        guard let bucket = object.bucket else {
            statusMessage = "Missing bucket name."
            return
        }
        let destination = renameDestination.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !destination.isEmpty, destination != object.name else { return }
        guard await WriteGate.ensureUnlocked(env: env, reason: "Rename Cloud Storage object") else { return }
        busy = true
        defer { busy = false }
        do {
            _ = try await env.storageService.copyObject(
                bucket: bucket,
                sourceName: object.name,
                destinationName: destination
            )
            try await env.storageService.deleteObject(bucket: bucket, name: object.name)
            statusMessage = "Renamed to \(destination)."
            await env.audit.record(AuditEntry(
                accountID: env.accountManager.activeAccountID,
                projectID: projectID,
                action: "storage.rename",
                resource: object.name,
                summary: "Renamed storage object",
                reversible: false,
                beforeValue: object.name,
                afterValue: destination
            ))
            dismiss()
        } catch let error as APIError {
            statusMessage = error.userMessage
        } catch {
            statusMessage = "Rename failed."
        }
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(label).foregroundStyle(Theme.Palette.textSecondary)
            Spacer()
            Text(value)
                .foregroundStyle(Theme.Palette.textPrimary)
                .multilineTextAlignment(.trailing)
                .textSelection(.enabled)
        }
    }

    private func copyableRow(_ label: String, _ value: String, mono: Bool = false) -> some View {
        HStack(alignment: .top) {
            Text(label).foregroundStyle(Theme.Palette.textSecondary)
            Spacer()
            Text(value)
                .font(mono ? .pcMonoSmall : .body)
                .foregroundStyle(Theme.Palette.textPrimary)
                .multilineTextAlignment(.trailing)
                .textSelection(.enabled)
        }
        .contextMenu {
            Button {
                UIPasteboard.general.string = value
            } label: {
                Label("Copy \(label)", systemImage: "doc.on.doc")
            }
        }
    }
}
