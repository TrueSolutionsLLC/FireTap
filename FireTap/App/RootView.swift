import SwiftUI

/// Top-level router. Chooses between the signed-out welcome flow, the project
/// picker, and the in-project tabbed console.
struct RootView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Group {
                if env.accountManager.phase == .restoring {
                    ZStack {
                        Theme.Palette.background.ignoresSafeArea()
                        ProgressView("Restoring session…")
                            .accessibilityLabel("Restoring signed-in session")
                    }
                } else if !env.accountManager.isSignedIn {
                    WelcomeView()
                } else if env.isRestoringProject {
                    ZStack {
                        Theme.Palette.background.ignoresSafeArea()
                        ProgressView("Opening last project…")
                            .accessibilityLabel("Opening last project")
                    }
                } else if let project = env.selectedProject {
                    MainTabView(project: project)
                        .id(project.id)
                } else {
                    ProjectPickerView()
                }
            }
            .animation(reduceMotion ? nil : .snappy, value: env.accountManager.isSignedIn)
            .animation(reduceMotion ? nil : .snappy, value: env.selectedProject?.id)
            .animation(reduceMotion ? nil : .snappy, value: env.accountManager.phase == .restoring)

            if env.appLock.screenshotPrivacyEnabled, scenePhase != .active {
                PrivacyBlurOverlay()
            }

            if env.appLock.isEnabled, env.appLock.isLocked {
                AppLockOverlay()
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                env.appLock.noteActivity()
            } else {
                env.appLock.handleResignActive()
                env.safeMode.relock()
            }
        }
    }
}
