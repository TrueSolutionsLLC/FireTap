import SwiftUI

/// Lists the project's real Cloud Storage buckets, then navigates into a
/// folder-scoped, paginated object browser with upload/download/write actions.
struct StorageBrowserView: View {
    let project: FirebaseProject
    @Environment(AppEnvironment.self) private var env
    @State private var phase: AsyncPhase<[StorageBucket]> = .idle

    var body: some View {
        Group {
            switch phase {
            case .idle, .loading:
                LoadingStateView().padding()
            case .failed(let error):
                ErrorStateView(error: error) { Task { await loadTask() } }
            case .loaded(let buckets):
                if buckets.isEmpty {
                    EmptyStateView(
                        title: "No buckets",
                        message: "This project has no Cloud Storage buckets, or your account can't list them.",
                        systemImage: "externaldrive"
                    )
                } else {
                    bucketList(buckets)
                }
            }
        }
        .appBackground()
        .navigationTitle("Cloud Storage")
        .navigationBarTitleDisplayMode(.inline)
        .task { if phase.value == nil { await loadTask() } }
    }

    private func bucketList(_ buckets: [StorageBucket]) -> some View {
        List {
            Section("Buckets • \(buckets.count)") {
                ForEach(buckets) { bucket in
                    NavigationLink {
                        StorageObjectListView(projectID: project.projectId, bucket: bucket.name, prefix: "", title: bucket.name)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(bucket.name)
                                .font(.pcBodyEmphasis)
                                .foregroundStyle(Theme.Palette.textPrimary)
                                .lineLimit(1)
                            HStack(spacing: 6) {
                                if let location = bucket.location {
                                    Text(location).font(.pcCaption).foregroundStyle(Theme.Palette.textSecondary)
                                }
                                if let storageClass = bucket.storageClass {
                                    Text("• \(storageClass)").font(.pcCaption).foregroundStyle(Theme.Palette.textTertiary)
                                }
                            }
                        }
                    }
                    .listRowBackground(Theme.Palette.surface)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .refreshable { await loadTask() }
    }

    private func loadTask() async {
        if phase.value == nil { phase = .loading }
        do {
            let buckets = try await env.storageService.listBuckets(projectID: project.projectId)
            phase = .loaded(buckets)
        } catch let error as APIError {
            phase = .failed(error)
        } catch {
            phase = .failed(.transport(underlying: "unknown"))
        }
    }
}
