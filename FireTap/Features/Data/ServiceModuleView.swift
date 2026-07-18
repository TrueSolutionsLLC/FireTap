import SwiftUI

struct ServiceModuleView: View {
    let module: ServiceModule
    let project: FirebaseProject
    @Environment(AppEnvironment.self) private var env

    var body: some View {
        destination
            .task {
                guard let account = env.accountManager.activeAccountID else { return }
                env.preferences.recordRecentlyViewed(
                    ResourceKey.module(module),
                    account: account
                )
            }
    }

    @ViewBuilder
    private var destination: some View {
        switch module {
        case .firestore:
            FirestoreBrowserView(project: project)
        case .authentication:
            AuthUsersView(project: project)
        case .storage:
            StorageBrowserView(project: project)
        case .functions:
            FunctionsBrowserView(project: project)
        case .logs:
            LogsBrowserView(project: project)
        case .realtimeDatabase:
            RealtimeDatabaseBrowserView(project: project)
        case .remoteConfig:
            RemoteConfigBrowserView(project: project)
        case .hosting:
            HostingBrowserView(project: project)
        case .appCheck:
            AppCheckBrowserView(project: project)
        case .iam:
            IAMBrowserView(project: project)
        case .fcm:
            FCMTestMessageView(project: project)
        case .appDistribution:
            AppDistributionBrowserView(project: project)
        case .extensions:
            ExtensionsBrowserView(project: project)
        case .rules:
            RulesBrowserView(project: project)
        case .billing:
            ModuleUnavailableView(module: module)
        }
    }
}

struct ModuleUnavailableView: View {
    let module: ServiceModule

    var body: some View {
        ContentUnavailableView {
            Label(module.title, systemImage: module.symbol)
        } description: {
            VStack(spacing: Theme.Spacing.sm) {
                Text("This module connects to the \(module.backingAPI).")
                Text("It isn’t available as a live screen in this build yet. The directory never shows a working-looking control for an unsupported operation.")
                    .font(.pcCaption)
                    .foregroundStyle(Theme.Palette.textSecondary)
            }
        }
        .appBackground()
        .navigationTitle(module.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
