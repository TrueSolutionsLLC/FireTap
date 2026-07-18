import SwiftUI

/// Shared pattern for Phase 4–7 module browsers: load live data, show honest
/// states, never fabricate rows.
struct LiveServiceListView<Item: Identifiable & Sendable, Row: View>: View {
    let title: String
    let symbol: String
    let emptyTitle: String
    let emptyMessage: String
    let load: () async throws -> [Item]
    @ViewBuilder let row: (Item) -> Row

    @State private var phase: AsyncPhase<[Item]> = .idle

    var body: some View {
        Group {
            switch phase {
            case .idle, .loading:
                LoadingStateView().padding()
            case .failed(let error):
                ErrorStateView(error: error) { Task { await reload() } }
            case .loaded(let items):
                if items.isEmpty {
                    EmptyStateView(title: emptyTitle, message: emptyMessage, systemImage: symbol, actionTitle: "Try again") {
                        Task { await reload() }
                    }
                } else {
                    List {
                        Section("\(items.count)") {
                            ForEach(items) { item in
                                row(item).listRowBackground(Theme.Palette.surface)
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                    .refreshable { await reload() }
                }
            }
        }
        .appBackground()
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .task { if phase.value == nil { await reload() } }
    }

    private func reload() async {
        if phase.value == nil { phase = .loading }
        do {
            phase = .loaded(try await load())
        } catch let error as APIError {
            phase = .failed(error)
        } catch {
            phase = .failed(.transport(underlying: "unknown"))
        }
    }
}
