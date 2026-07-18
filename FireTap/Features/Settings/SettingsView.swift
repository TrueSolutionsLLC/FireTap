import SwiftUI

/// Settings: account management, security, Pro, and legal.
struct SettingsView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.scenePhase) private var scenePhase
    @State private var confirmDeleteCredentials = false
    @State private var showingAccountSheet = false

    private var accountManager: AccountManager { env.accountManager }

    var body: some View {
        NavigationStack {
            List {
                accountsSection
                costGuardSection
                securitySection
                proSection
                aboutSection
                dangerSection
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .appBackground()
            .navigationTitle("Settings")
            .sheet(isPresented: $showingAccountSheet) {
                AccountSwitcherSheet()
            }
            .confirmationDialog(
                "Delete all local credentials?",
                isPresented: $confirmDeleteCredentials,
                titleVisibility: .visible
            ) {
                Button("Delete Local Credentials", role: .destructive) {
                    Task {
                        env.handleAccountSessionChange()
                        await accountManager.deleteLocalCredentials()
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This removes the Google Sign-In session from this device. Your Google account grant is not revoked — use Disconnect for that.")
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    env.appLock.noteActivity()
                }
            }
        }
    }

    private var accountsSection: some View {
        Section("Connected account") {
            if let account = accountManager.activeAccount {
                Button {
                    showingAccountSheet = true
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(account.displayName ?? account.email)
                                .foregroundStyle(Theme.Palette.textPrimary)
                            Text(account.email)
                                .font(.pcCaption)
                                .foregroundStyle(Theme.Palette.textSecondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.Palette.textTertiary)
                    }
                }
                .listRowBackground(Theme.Palette.surface)
                .accessibilityLabel("Signed in as \(account.email)")
            } else {
                Text("Not signed in")
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .listRowBackground(Theme.Palette.surface)
            }

            Button {
                showingAccountSheet = true
            } label: {
                Label("Switch or manage account", systemImage: "person.crop.circle.badge.plus")
            }
            .listRowBackground(Theme.Palette.surface)
        }
    }

    @ViewBuilder
    private var costGuardSection: some View {
        if let project = env.selectedProject {
            Section("Cost Guard") {
                NavigationLink {
                    CostGuardView(project: project)
                } label: {
                    Label("Session usage for \(project.name)", systemImage: "gauge.with.dots.needle.33percent")
                }
                .listRowBackground(Theme.Palette.surface)
            }
        }
    }

    private var securitySection: some View {
        Section("Security") {
            Toggle(isOn: appLockEnabledBinding) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("App Lock")
                    Text("Require \(env.appLock.biometryName) when opening FireTap and after inactivity.")
                        .font(.pcCaption)
                        .foregroundStyle(Theme.Palette.textSecondary)
                }
            }
            .listRowBackground(Theme.Palette.surface)

            if env.appLock.isEnabled {
                Picker("Inactivity timeout", selection: appLockTimeoutBinding) {
                    ForEach(AppLockController.InactivityTimeout.allCases) { timeout in
                        Text(timeout.title).tag(timeout)
                    }
                }
                .listRowBackground(Theme.Palette.surface)
            }

            Toggle(isOn: screenshotPrivacyBinding) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Screenshot privacy")
                    Text("Hide app content in the app switcher and when the app is inactive.")
                        .font(.pcCaption)
                        .foregroundStyle(Theme.Palette.textSecondary)
                }
            }
            .listRowBackground(Theme.Palette.surface)

            LabeledContent("Sign-in", value: "Google Sign-In (PKCE)")
                .listRowBackground(Theme.Palette.surface)
            LabeledContent("Data path", value: "Device ↔ Google")
                .listRowBackground(Theme.Palette.surface)
            LabeledContent("Credentials", value: "SDK Keychain")
                .listRowBackground(Theme.Palette.surface)
            LabeledContent("Initial access", value: "Identity + Firebase read-only")
                .listRowBackground(Theme.Palette.surface)
        }
    }

    private var appLockEnabledBinding: Binding<Bool> {
        Binding(
            get: { env.appLock.isEnabled },
            set: { env.appLock.isEnabled = $0 }
        )
    }

    private var appLockTimeoutBinding: Binding<AppLockController.InactivityTimeout> {
        Binding(
            get: { env.appLock.inactivityTimeout },
            set: { env.appLock.inactivityTimeout = $0 }
        )
    }

    private var screenshotPrivacyBinding: Binding<Bool> {
        Binding(
            get: { env.appLock.screenshotPrivacyEnabled },
            set: { env.appLock.screenshotPrivacyEnabled = $0 }
        )
    }

    @ViewBuilder
    private var proSection: some View {
        let store = env.store
        Section("FireTap Pro") {
            LabeledContent("Status", value: store.isPro ? "Pro (lifetime)" : "Free")
                .listRowBackground(Theme.Palette.surface)

            if !store.isPro {
                Text("Pro unlocks multiple connected projects and write / admin actions. One-time purchase — no subscription.")
                    .font(.pcCaption)
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .listRowBackground(Theme.Palette.surface)

                Button {
                    Task { await store.purchase() }
                } label: {
                    HStack {
                        Text("Unlock Pro")
                        Spacer()
                        if store.phase == .purchasing {
                            ProgressView()
                        } else if let price = store.displayPrice {
                            Text(price).foregroundStyle(Theme.Palette.textSecondary)
                        }
                    }
                }
                .disabled(store.proProduct == nil || store.phase == .purchasing)
                .listRowBackground(Theme.Palette.surface)

                if store.productLoadFailed {
                    Text("The Pro product couldn't be loaded from the App Store. Check your connection and try again.")
                        .font(.pcCaption)
                        .foregroundStyle(Theme.Palette.warning)
                        .listRowBackground(Theme.Palette.surface)

                    Button("Retry Loading Product") {
                        Task { await store.loadProduct() }
                    }
                    .listRowBackground(Theme.Palette.surface)
                }

                Button("Restore Purchases") {
                    Task { await store.restore() }
                }
                .listRowBackground(Theme.Palette.surface)
            }

            if case .pending = store.phase {
                Text("Your purchase is pending approval. Pro will unlock when the transaction completes.")
                    .font(.pcCaption)
                    .foregroundStyle(Theme.Palette.warning)
                    .listRowBackground(Theme.Palette.surface)
            }

            if let message = store.lastTransactionStateMessage {
                Text(message)
                    .font(.pcCaption)
                    .foregroundStyle(Theme.Palette.warning)
                    .listRowBackground(Theme.Palette.surface)
            }

            if case .failed(let message) = store.phase {
                Text(message)
                    .font(.pcCaption)
                    .foregroundStyle(Theme.Palette.danger)
                    .listRowBackground(Theme.Palette.surface)
            }
        }
    }

    private var aboutSection: some View {
        Section("About") {
            LabeledContent("Version", value: "\(AppConfig.marketingVersion) (\(AppConfig.buildNumber))")
                .listRowBackground(Theme.Palette.surface)

            ForEach(LegalDocument.allCases) { document in
                NavigationLink {
                    LegalDocumentView(document: document)
                } label: {
                    Text(document.title)
                }
                .listRowBackground(Theme.Palette.surface)
            }

            if let url = AppConfig.privacyPolicyURL {
                Link("Privacy Policy (web)", destination: url).listRowBackground(Theme.Palette.surface)
            }
            if let url = AppConfig.termsURL {
                Link("Terms of Use (web)", destination: url).listRowBackground(Theme.Palette.surface)
            }
            if let url = AppConfig.supportURL {
                Link("Support (web)", destination: url).listRowBackground(Theme.Palette.surface)
            }
        }
    }

    private var dangerSection: some View {
        Section {
            if let active = accountManager.activeAccount {
                Button("Disconnect \(active.email)", role: .destructive) {
                    Task {
                        env.handleAccountSessionChange()
                        await accountManager.disconnect(accountID: active.id)
                    }
                }
                .listRowBackground(Theme.Palette.surface)
            }
            Button("Delete Local Credentials", role: .destructive) {
                confirmDeleteCredentials = true
            }
            .listRowBackground(Theme.Palette.surface)
        } footer: {
            Text("FireTap does not create FireTap accounts. You sign in with Google; disconnecting or deleting local credentials does not delete your Google account. Disconnect revokes this app's access with Google and removes the local session.")
        }
    }
}
