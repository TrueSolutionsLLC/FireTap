import SwiftUI

/// Explains every requested Google permission *before* authorization begins,
/// as required for transparent OAuth consent.
struct ScopeConsentView: View {
    let onContinue: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    Text("Before you connect")
                        .font(.pcTitle)
                        .foregroundStyle(Theme.Palette.textPrimary)
                    Text("Google will ask you to approve the access below. You sign in on Google's own website — this app never sees your password.")
                        .font(.pcBody)
                        .foregroundStyle(Theme.Palette.textSecondary)

                    ForEach(AppConfig.oauthScopes) { scope in
                        Card {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(scope.title)
                                    .font(.pcBodyEmphasis)
                                    .foregroundStyle(Theme.Palette.textPrimary)
                                Text(scope.explanation)
                                    .font(.pcCaption)
                                    .foregroundStyle(Theme.Palette.textSecondary)
                            }
                        }
                    }

                    Label("You can disconnect and delete local credentials at any time in Settings.", systemImage: "info.circle")
                        .font(.pcCaption)
                        .foregroundStyle(Theme.Palette.textSecondary)
                        .padding(.top, Theme.Spacing.sm)
                }
                .padding(Theme.Spacing.xl)
            }
            .appBackground()
            .safeAreaInset(edge: .bottom) {
                Button(action: onContinue) {
                    Text("Continue to Google")
                        .font(.pcBodyEmphasis)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Theme.Palette.accent, in: RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, Theme.Spacing.xl)
                .padding(.bottom, Theme.Spacing.md)
                .accessibilityIdentifier("consent.continue")
            }
            .navigationTitle("Permissions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
