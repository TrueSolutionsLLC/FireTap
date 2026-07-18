import SwiftUI

/// Account switcher: shows the connected Google account and actions to switch,
/// sign out, disconnect (revoke), or delete local credentials.
struct AccountSwitcherSheet: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss
    @State private var confirmDelete = false

    private var accountManager: AccountManager { env.accountManager }

    var body: some View {
        NavigationStack {
            List {
                if let account = accountManager.activeAccount {
                    Section("Signed in") {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(account.displayName ?? account.email)
                                .font(.pcBodyEmphasis)
                                .foregroundStyle(Theme.Palette.textPrimary)
                            Text(account.email)
                                .font(.pcCaption)
                                .foregroundStyle(Theme.Palette.textSecondary)
                        }
                        .listRowBackground(Theme.Palette.surface)
                        .accessibilityElement(children: .combine)
                    }
                }

                Section {
                    Button {
                        Task {
                            env.handleAccountSessionChange()
                            await accountManager.switchAccount()
                            if accountManager.isSignedIn {
                                await env.restoreLastProjectIfAccessible()
                                dismiss()
                            }
                        }
                    } label: {
                        Label("Use a different Google account", systemImage: "person.crop.circle.badge.plus")
                    }
                    .listRowBackground(Theme.Palette.surface)
                    .disabled(accountManager.phase == .authenticating)

                    if accountManager.phase == .authenticating {
                        HStack {
                            ProgressView()
                            Text("Waiting for Google…")
                                .foregroundStyle(Theme.Palette.textSecondary)
                        }
                        .listRowBackground(Theme.Palette.surface)
                    }
                }

                Section {
                    Button("Sign out", role: .destructive) {
                        Task {
                            env.handleAccountSessionChange()
                            await accountManager.signOut()
                            dismiss()
                        }
                    }
                    .listRowBackground(Theme.Palette.surface)

                    if let account = accountManager.activeAccount {
                        Button("Disconnect \(account.email)", role: .destructive) {
                            Task {
                                env.handleAccountSessionChange()
                                await accountManager.disconnect(accountID: account.id)
                                dismiss()
                            }
                        }
                        .listRowBackground(Theme.Palette.surface)
                    }

                    Button("Delete Local Credentials", role: .destructive) {
                        confirmDelete = true
                    }
                    .listRowBackground(Theme.Palette.surface)
                } footer: {
                    Text("Sign out clears this device’s Google Sign-In session. Disconnect also revokes FireTap’s access with Google. Delete Local Credentials only removes local session data.")
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .appBackground()
            .navigationTitle("Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .confirmationDialog(
                "Delete all local credentials?",
                isPresented: $confirmDelete,
                titleVisibility: .visible
            ) {
                Button("Delete Local Credentials", role: .destructive) {
                    Task {
                        env.handleAccountSessionChange()
                        await accountManager.deleteLocalCredentials()
                        dismiss()
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This removes the Google Sign-In session from this device. Your Google account grant is not revoked — use Disconnect for that.")
            }
        }
        .presentationDetents([.medium, .large])
    }
}
