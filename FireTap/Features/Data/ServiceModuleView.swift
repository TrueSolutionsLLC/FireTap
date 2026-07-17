import SwiftUI

/// Routes a `ServiceModule` to its implementation. Modules that are wired to a
/// live API render their real browser; the rest render an honest availability
/// state that names the backing API — never a fake, working-looking screen.
struct ServiceModuleView: View {
    let module: ServiceModule
    let project: FirebaseProject

    var body: some View {
        switch module {
        case .firestore:
            FirestoreBrowserView(project: project)
        case .authentication:
            AuthUsersView(project: project)
        case .storage:
            StorageBrowserView(project: project)
        default:
            ModuleUnavailableView(module: module)
        }
    }
}

/// Honest "not in this build" state. Clearly communicates status rather than
/// showing a non-functional UI.
struct ModuleUnavailableView: View {
    let module: ServiceModule

    var body: some View {
        ContentUnavailableView {
            Label(module.title, systemImage: module.symbol)
        } description: {
            VStack(spacing: Theme.Spacing.sm) {
                Text("This module connects to the \(module.backingAPI).")
                Text("It isn't available in this build yet. When enabled, it will read your live data directly from Google with no data passing through any app-owned server.")
                    .font(.pcCaption)
                    .foregroundStyle(Theme.Palette.textSecondary)
            }
        }
        .appBackground()
        .navigationTitle(module.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
