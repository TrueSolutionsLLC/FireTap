import SwiftUI

/// Requires the user to type an exact resource name before a destructive action.
struct TypedConfirmationSheet: View {
    let title: String
    let message: String
    let confirmPhrase: String
    let confirmButtonTitle: String
    var isProduction: Bool = false
    let onConfirm: () -> Void
    let onCancel: () -> Void

    @State private var typed = ""
    @Environment(\.dismiss) private var dismiss

    private var matches: Bool {
        typed.trimmingCharacters(in: .whitespacesAndNewlines) == confirmPhrase
    }

    var body: some View {
        NavigationStack {
            Form {
                if isProduction {
                    Section {
                        Label("Production project", systemImage: "exclamationmark.shield.fill")
                            .foregroundStyle(Theme.Palette.danger)
                    }
                }
                Section {
                    Text(message)
                        .font(.pcBody)
                        .foregroundStyle(Theme.Palette.textSecondary)
                    Text("Type \(confirmPhrase) to confirm.")
                        .font(.pcCaption)
                        .foregroundStyle(Theme.Palette.textTertiary)
                    TextField("Confirmation", text: $typed)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.pcMono)
                        .accessibilityLabel("Type \(confirmPhrase) to confirm")
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(confirmButtonTitle, role: .destructive) {
                        onConfirm()
                        dismiss()
                    }
                    .disabled(!matches)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

/// Shared write gate messaging for Pro + Safe Mode + incremental write scopes.
enum WriteGate {
    @MainActor
    static func message(env: AppEnvironment) -> (text: String, symbol: String)? {
        if !env.featureGate.canOfferWrites {
            return ("Write and admin actions require FireTap Pro.", "star.circle")
        }
        if !env.accountManager.hasWriteScopes {
            return (
                "Google write access hasn’t been granted yet. Unlock will request additional scopes.",
                "person.badge.key"
            )
        }
        if env.selectedProjectEnvironment.isProduction && !env.safeMode.isWriteUnlocked {
            return (
                "Production Safe Mode is locked. Unlock with \(env.safeMode.biometryName) to continue.",
                "lock.shield"
            )
        }
        if !env.safeMode.isWriteUnlocked {
            return (
                "Unlock write access with \(env.safeMode.biometryName) before making changes.",
                "lock"
            )
        }
        return nil
    }

    /// Ensures Pro entitlement, incremental Google write scopes, and biometric unlock.
    @MainActor
    static func ensureUnlocked(env: AppEnvironment, reason: String) async -> Bool {
        guard env.featureGate.canOfferWrites else { return false }
        if !env.accountManager.hasWriteScopes {
            do {
                try await env.accountManager.requestWriteScopes()
            } catch {
                return false
            }
            guard env.accountManager.hasWriteScopes else { return false }
        }
        if env.safeMode.isWriteUnlocked {
            env.safeMode.noteActivity()
            return true
        }
        return await env.safeMode.requestWriteUnlock(reason: reason)
    }
}
