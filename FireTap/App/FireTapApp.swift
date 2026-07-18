import SwiftUI
import GoogleSignIn

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
                    environment.appLock.configureOnLaunch()
                    await environment.accountManager.bootstrap()
                    if environment.accountManager.isSignedIn {
                        await environment.restoreLastProjectIfAccessible()
                        await environment.resolvePendingDeepLink()
                    }
                    environment.store.start()
                }
                .onOpenURL { url in
                    if GIDSignIn.sharedInstance.handle(url) {
                        return
                    }
                    Task {
                        await environment.handleDeepLink(url)
                    }
                }
                .onChange(of: environment.accountManager.activeAccountID) { _, newID in
                    if newID == nil {
                        environment.handleAccountSessionChange()
                    } else {
                        Task {
                            await environment.restoreLastProjectIfAccessible()
                            await environment.resolvePendingDeepLink()
                        }
                    }
                }
                .onChange(of: environment.accountManager.isSignedIn) { _, isSignedIn in
                    guard isSignedIn else { return }
                    Task { await environment.resolvePendingDeepLink() }
                }
        }
    }
}
