import SwiftUI

/// The Data tab: a searchable directory of every service module for the
/// current project.
struct DataDirectoryView: View {
    let project: FirebaseProject
    @State private var searchText = ""

    private var filtered: [ServiceModule] {
        let needle = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        guard !needle.isEmpty else { return ServiceModule.allCases }
        return ServiceModule.allCases.filter { $0.title.lowercased().contains(needle) }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(filtered) { module in
                        NavigationLink {
                            ServiceModuleView(module: module, project: project)
                        } label: {
                            Label {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(module.title)
                                        .foregroundStyle(Theme.Palette.textPrimary)
                                    Text(module.backingAPI)
                                        .font(.pcMonoSmall)
                                        .foregroundStyle(Theme.Palette.textTertiary)
                                }
                            } icon: {
                                Image(systemName: module.symbol)
                                    .foregroundStyle(module.tint)
                            }
                        }
                        .listRowBackground(Theme.Palette.surface)
                    }
                } header: {
                    Text(project.name)
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .appBackground()
            .navigationTitle("Data")
            .searchable(text: $searchText, prompt: "Search services")
        }
    }
}
