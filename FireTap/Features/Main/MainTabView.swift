import SwiftUI

/// In-project console. Four primary tabs (Figma tab bar): Command Center, Data,
/// Activity, Settings. On iPad (regular width) uses a split view with a service
/// module sidebar. A persistent production indicator is shown for production projects.
struct MainTabView: View {
    let project: FirebaseProject
    @Environment(AppEnvironment.self) private var env
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selection: Tab = .home
    @State private var sidebarModule: ServiceModule?
    @State private var sidebarDestination: SidebarDestination = .commandCenter

    enum Tab: Hashable { case home, data, activity, settings }

    enum SidebarDestination: Hashable {
        case commandCenter
        case activity
        case settings
    }

    var body: some View {
        VStack(spacing: 0) {
            if env.selectedProjectEnvironment.isProduction {
                ProductionIndicator(readOnly: !env.safeMode.isWriteUnlocked)
            }
            if horizontalSizeClass == .regular {
                iPadLayout
            } else {
                phoneLayout
            }
        }
        .onChange(of: env.pendingNavigationModule) { _, module in
            guard let module else { return }
            if horizontalSizeClass == .regular {
                sidebarModule = module
                sidebarDestination = .commandCenter
            } else {
                selection = .data
            }
            env.clearPendingNavigationModule()
        }
    }

    private var phoneLayout: some View {
        TabView(selection: $selection) {
            CommandCenterView(project: project)
                .tabItem { Label("Home", systemImage: "house.fill") }
                .tag(Tab.home)

            DataDirectoryView(project: project)
                .tabItem { Label("Data", systemImage: "tablecells") }
                .tag(Tab.data)

            ActivityView(project: project)
                .tabItem { Label("Activity", systemImage: "dot.radiowaves.up.forward") }
                .tag(Tab.activity)

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                .tag(Tab.settings)
        }
    }

    private var iPadLayout: some View {
        NavigationSplitView {
            List(selection: $sidebarModule) {
                Section("Console") {
                    Button {
                        sidebarDestination = .commandCenter
                        sidebarModule = nil
                    } label: {
                        Label("Command Center", systemImage: "house.fill")
                    }
                    .listRowBackground(Theme.Palette.surface)

                    Button {
                        sidebarDestination = .activity
                        sidebarModule = nil
                    } label: {
                        Label("Incident Center", systemImage: "exclamationmark.triangle.fill")
                    }
                    .listRowBackground(Theme.Palette.surface)

                    Button {
                        sidebarDestination = .settings
                        sidebarModule = nil
                    } label: {
                        Label("Settings", systemImage: "gearshape.fill")
                    }
                    .listRowBackground(Theme.Palette.surface)
                }

                Section("Services") {
                    ForEach(ServiceModule.allCases) { module in
                        NavigationLink(value: module) {
                            Label {
                                Text(module.title)
                            } icon: {
                                Image(systemName: module.symbol)
                                    .foregroundStyle(module.tint)
                            }
                        }
                        .listRowBackground(Theme.Palette.surface)
                    }
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            .appBackground()
            .navigationTitle(project.name)
        } detail: {
            Group {
                if let module = sidebarModule {
                    ServiceModuleView(module: module, project: project)
                } else {
                    switch sidebarDestination {
                    case .commandCenter:
                        CommandCenterView(project: project)
                    case .activity:
                        ActivityView(project: project)
                    case .settings:
                        SettingsView()
                    }
                }
            }
            .appBackground()
        }
        .navigationSplitViewStyle(.balanced)
        .animation(reduceMotion ? nil : .default, value: sidebarModule?.id)
    }
}
