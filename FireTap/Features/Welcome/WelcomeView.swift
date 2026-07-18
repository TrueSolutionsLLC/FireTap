import SwiftUI

/// Signed-out welcome screen (Figma "01 — Welcome"). Explains the privacy model
/// and starts the Google sign-in flow. When OAuth isn't configured, it shows an
/// honest configuration state instead of a button that can't work.
struct WelcomeView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var showingConsent = false

    private var accountManager: AccountManager { env.accountManager }

    var body: some View {
        ZStack {
            Theme.Palette.background.ignoresSafeArea()
            VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                Spacer(minLength: Theme.Spacing.xxl)
                productMark
                hero
                privacyPromise
                Spacer()
                actions
                disclaimer
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
            .frame(maxWidth: 520)
        }
        .sheet(isPresented: $showingConsent) {
            ScopeConsentView {
                showingConsent = false
                Task {
                    await accountManager.signIn()
                    if accountManager.isSignedIn {
                        await env.restoreLastProjectIfAccessible()
                    }
                }
            }
        }
        .alert(
            "Sign-in problem",
            isPresented: .init(
                get: { if case .failed = accountManager.phase { return true } else { return false } },
                set: { if !$0 { accountManager.clearError() } }
            ),
            presenting: currentError
        ) { _ in
            Button("OK", role: .cancel) { accountManager.clearError() }
        } message: { error in
            Text(error.userMessage)
        }
    }

    private var currentError: AuthError? {
        if case .failed(let error) = accountManager.phase { return error }
        return nil
    }

    private var productMark: some View {
        Image(systemName: "bolt.horizontal.circle.fill")
            .font(.system(size: 56))
            .foregroundStyle(Theme.Palette.accent)
            .accessibilityHidden(true)
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text("FIREBASE, WITHOUT THE DESKTOP")
                .font(.pcLabel)
                .foregroundStyle(Theme.Palette.accent)
                .tracking(1.2)
            Text("Your backend.\nRight in your pocket.")
                .font(.system(size: 40, weight: .bold))
                .foregroundStyle(Theme.Palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Text("Inspect, monitor, and safely manage every project from a native console built for iPhone and iPad.")
                .font(.pcBody)
                .foregroundStyle(Theme.Palette.textSecondary)
        }
    }

    private var privacyPromise: some View {
        Card {
            HStack(alignment: .top, spacing: Theme.Spacing.md) {
                Image(systemName: "lock.shield.fill")
                    .font(.title2)
                    .foregroundStyle(Theme.Palette.healthy)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Private by architecture")
                        .font(.pcBodyEmphasis)
                        .foregroundStyle(Theme.Palette.textPrimary)
                    Text("Your project data never passes through our servers. Requests go straight from your device to Google.")
                        .font(.pcCaption)
                        .foregroundStyle(Theme.Palette.textSecondary)
                }
            }
        }
    }

    @ViewBuilder
    private var actions: some View {
        if !accountManager.isConfigured {
            NotConfiguredStateView()
                .frame(maxWidth: .infinity)
        } else {
            Button {
                showingConsent = true
            } label: {
                HStack(spacing: Theme.Spacing.md) {
                    if accountManager.phase == .authenticating || accountManager.phase == .restoring {
                        ProgressView().tint(.white)
                    } else {
                        Image(systemName: "g.circle.fill")
                    }
                    Text(signInLabel)
                        .font(.pcBodyEmphasis)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(Theme.Palette.accent, in: RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous))
                .foregroundStyle(.white)
            }
            .disabled(accountManager.phase == .authenticating || accountManager.phase == .restoring)
            .accessibilityIdentifier("welcome.continueWithGoogle")
        }
    }

    private var disclaimer: some View {
        Text("FireTap is an independent tool and is not affiliated with, endorsed by, or sponsored by Google or Apple. Firebase and Google Cloud are trademarks of Google LLC.")
            .font(.pcCaption)
            .foregroundStyle(Theme.Palette.textTertiary)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityLabel("Independent app disclaimer. FireTap is not affiliated with Google or Apple. Firebase and Google Cloud are trademarks of Google LLC.")
    }

    private var signInLabel: String {
        switch accountManager.phase {
        case .restoring: return "Restoring session…"
        case .authenticating: return "Waiting for Google…"
        default: return "Continue with Google"
        }
    }
}
