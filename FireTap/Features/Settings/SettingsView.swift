import SwiftUI

/// Settings: account management (multi-account), security, Pro, and legal.
struct SettingsView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var confirmDeleteCredentials = false

    private var accountManager: AccountManager { env.accountManager }

    var body: some View {
        NavigationStack {
            List {
                accountsSection
                securitySection
                proSection
                aboutSection
                dangerSection
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .appBackground()
            .navigationTitle("Settings")
        }
        .confirmationDialog(
            "Delete all local credentials?",
            isPresented: $confirmDeleteCredentials,
            titleVisibility: .visible
        ) {
            Button("Delete Local Credentials", role: .destructive) {
                Task { await accountManager.deleteLocalCredentials() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes stored tokens from this device. Your Google account grant is not revoked — use Disconnect for that.")
        }
    }

    private var accountsSection: some View {
        Section("Connected accounts") {
            ForEach(accountManager.accounts) { account in
                Button {
                    Task { await accountManager.setActiveAccount(account.id) }
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
                        if account.id == accountManager.activeAccountID {
                            Image(systemName: "checkmark").foregroundStyle(Theme.Palette.accent)
                        }
                    }
                }
                .swipeActions {
                    Button("Disconnect", role: .destructive) {
                        Task { await accountManager.disconnect(accountID: account.id) }
                    }
                }
                .listRowBackground(Theme.Palette.surface)
            }
            Button {
                Task { await accountManager.signIn() }
            } label: {
                Label("Add account", systemImage: "plus.circle")
            }
            .listRowBackground(Theme.Palette.surface)
        }
    }

    private var securitySection: some View {
        Section("Security") {
            LabeledContent("Data path", value: "Device ↔ Google")
                .listRowBackground(Theme.Palette.surface)
            LabeledContent("Credentials", value: "iOS Keychain")
                .listRowBackground(Theme.Palette.surface)
        }
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
                }

                Button("Restore Purchases") {
                    Task { await store.restore() }
                }
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
            if let url = AppConfig.privacyPolicyURL {
                Link("Privacy Policy", destination: url).listRowBackground(Theme.Palette.surface)
            }
            if let url = AppConfig.termsURL {
                Link("Terms of Use", destination: url).listRowBackground(Theme.Palette.surface)
            }
            if let url = AppConfig.supportURL {
                Link("Support", destination: url).listRowBackground(Theme.Palette.surface)
            }
        }
    }

    private var dangerSection: some View {
        Section {
            if let active = accountManager.activeAccount {
                Button("Disconnect \(active.email)", role: .destructive) {
                    Task { await accountManager.disconnect(accountID: active.id) }
                }
                .listRowBackground(Theme.Palette.surface)
            }
            Button("Delete Local Credentials", role: .destructive) {
                confirmDeleteCredentials = true
            }
            .listRowBackground(Theme.Palette.surface)
        } footer: {
            Text("Disconnect revokes this app's access with Google and removes the local credential. Delete Local Credentials only removes tokens from this device.")
        }
    }
}
