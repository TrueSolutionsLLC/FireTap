import SwiftUI

/// Top-level router. Chooses between the signed-out welcome flow, the project
/// picker, and the in-project tabbed console.
struct RootView: View {
    @Environment(AppEnvironment.self) private var env

    var body: some View {
        @Bindable var env = env
        Group {
            if !env.accountManager.isSignedIn {
                WelcomeView()
            } else if let project = env.selectedProject {
                MainTabView(project: project)
                    .id(project.id)
            } else {
                ProjectPickerView()
            }
        }
        .animation(.snappy, value: env.accountManager.isSignedIn)
        .animation(.snappy, value: env.selectedProject?.id)
    }
}
