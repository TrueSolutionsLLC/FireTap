import SwiftUI

/// Full-screen lock overlay shown when App Lock is enabled and the session is locked.
struct AppLockOverlay: View {
    @Environment(AppEnvironment.self) private var env
    @State private var isUnlocking = false

    var body: some View {
        ZStack {
            Theme.Palette.background.ignoresSafeArea()
            VStack(spacing: Theme.Spacing.lg) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(Theme.Palette.accent)
                    .accessibilityHidden(true)

                Text("\(AppConfig.displayName) is locked")
                    .font(.pcTitle)
                    .foregroundStyle(Theme.Palette.textPrimary)

                Text("Authenticate with \(env.appLock.biometryName) to continue.")
                    .font(.pcBody)
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .multilineTextAlignment(.center)

                if let error = env.appLock.lastUnlockError {
                    Text(error)
                        .font(.pcCaption)
                        .foregroundStyle(Theme.Palette.danger)
                        .multilineTextAlignment(.center)
                }

                Button {
                    Task { await unlock() }
                } label: {
                    HStack {
                        if isUnlocking { ProgressView().tint(.white) }
                        Text("Unlock")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.Palette.accent)
                .disabled(isUnlocking)
                .accessibilityLabel("Unlock \(AppConfig.displayName)")
                .accessibilityHint("Uses \(env.appLock.biometryName) to unlock the app")
            }
            .padding(Theme.Spacing.xxl)
        }
        .accessibilityElement(children: .contain)
    }

    private func unlock() async {
        isUnlocking = true
        defer { isUnlocking = false }
        _ = await env.appLock.unlock()
    }
}

/// Blurs app content in the app switcher / screenshots when privacy mode is on.
struct PrivacyBlurOverlay: View {
    var body: some View {
        Rectangle()
            .fill(.ultraThinMaterial)
            .ignoresSafeArea()
            .accessibilityLabel("App content hidden for privacy")
    }
}
