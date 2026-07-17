import SwiftUI

/// In-project console. Four primary tabs (Figma tab bar): Command Center, Data,
/// Activity, Settings. A persistent production indicator is shown for
/// production projects.
struct MainTabView: View {
    let project: FirebaseProject
    @Environment(AppEnvironment.self) private var env
    @State private var selection: Tab = .home

    enum Tab: Hashable { case home, data, activity, settings }

    var body: some View {
        VStack(spacing: 0) {
            if env.selectedProjectEnvironment.isProduction {
                ProductionIndicator(readOnly: true)
            }
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
    }
}
