import SwiftUI
import UIKit

/// Read-only object metadata. Download, preview, rename, move, and delete are
/// shown as honest gates — never a working-looking button — since they are not
/// wired to live endpoints yet and large files must never download implicitly.
struct StorageObjectDetailView: View {
    let object: StorageObject
    @Environment(AppEnvironment.self) private var env

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
            CardUnavailableNote(
                message: "Download and preview aren't available in this build. Large files must never download automatically, so this will be an explicit, size-aware action.",
                systemImage: "arrow.down.circle"
            )
            if env.selectedProjectEnvironment.isProduction {
                CardUnavailableNote(
                    message: "This is a production project. Renaming or deleting requires unlocking write access with \(env.safeMode.biometryName).",
                    systemImage: "lock.shield"
                )
            } else if !env.featureGate.canOfferWrites {
                CardUnavailableNote(
                    message: "Editing storage objects is a Pro feature. Free access is read-only.",
                    systemImage: "star.circle"
                )
            }
        } header: {
            Text("Actions")
        }
        .listRowBackground(Theme.Palette.surface)
    }

    private var fileName: String {
        object.name.split(separator: "/").last.map(String.init) ?? object.name
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
