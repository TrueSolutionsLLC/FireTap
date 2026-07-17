import SwiftUI

@main
struct FireTapApp: App {
    @State private var environment = AppEnvironment.live()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(environment)
                .tint(Theme.Palette.accent)
                .task {
                    await environment.accountManager.bootstrap()
                    environment.store.start()
                }
        }
        .onChange(of: scenePhase) { _, newPhase in
            // Relock Safe Mode writes whenever the app leaves the foreground.
            if newPhase != .active {
                environment.safeMode.relock()
            }
        }
    }
}
