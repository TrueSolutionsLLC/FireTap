import SwiftUI
import UIKit

/// Read-only detail for a single Authentication user: identity, providers,
/// verification/disabled state, timestamps, and custom claims. Management
/// actions are shown as an honest gate — they are not wired to live write
/// endpoints until verified against a real non-production project.
struct AuthUserDetailView: View {
    let user: AuthUser
    @Environment(AppEnvironment.self) private var env

    var body: some View {
        List {
            identitySection
            statusSection
            if !(user.providerUserInfo ?? []).isEmpty { providersSection }
            timestampsSection
            claimsSection
            managementSection
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .appBackground()
        .navigationTitle(user.primaryLabel)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var identitySection: some View {
        Section("Identity") {
            copyableRow("User UID", user.localId, mono: true)
            if let email = user.email { copyableRow("Email", email) }
            if let phone = user.phoneNumber { copyableRow("Phone", phone) }
            if let name = user.displayName, !name.isEmpty { detailRow("Display name", name) }
            if let tenant = user.tenantId { detailRow("Tenant", tenant) }
        }
        .listRowBackground(Theme.Palette.surface)
    }

    private var statusSection: some View {
        Section("Status") {
            HStack {
                Text("Account").foregroundStyle(Theme.Palette.textSecondary)
                Spacer()
                if user.isDisabled {
                    StatusChip(text: "Disabled", systemImage: "nosign",
                               color: Theme.Palette.danger, container: Theme.Palette.dangerContainer)
                } else {
                    StatusChip(text: "Enabled", systemImage: "checkmark.circle.fill")
                }
            }
            HStack {
                Text("Email verified").foregroundStyle(Theme.Palette.textSecondary)
                Spacer()
                Text(verifiedText)
                    .font(.pcBodyEmphasis)
                    .foregroundStyle(user.emailVerified == true ? Theme.Palette.healthy : Theme.Palette.textPrimary)
            }
            if user.isAnonymous {
                Label("Anonymous account", systemImage: "person.fill.questionmark")
                    .font(.pcCaption)
                    .foregroundStyle(Theme.Palette.textSecondary)
            }
        }
        .listRowBackground(Theme.Palette.surface)
    }

    private var providersSection: some View {
        Section("Sign-in providers • \((user.providerUserInfo ?? []).count)") {
            ForEach(user.providerUserInfo ?? []) { provider in
                VStack(alignment: .leading, spacing: 2) {
                    Text(AuthUser.friendlyProvider(provider.providerId ?? "unknown"))
                        .font(.pcBodyEmphasis)
                        .foregroundStyle(Theme.Palette.textPrimary)
                    if let detail = provider.email ?? provider.phoneNumber ?? provider.displayName {
                        Text(detail).font(.pcCaption).foregroundStyle(Theme.Palette.textSecondary)
                    }
                }
            }
        }
        .listRowBackground(Theme.Palette.surface)
    }

    private var timestampsSection: some View {
        Section("Activity") {
            timeRow("Created", user.createdDate)
            timeRow("Last sign-in", user.lastSignInDate)
            timeRow("Last token refresh", user.lastRefreshDate)
            if let validSince = user.validSinceDate {
                timeRow("Tokens valid since", validSince)
            }
        }
        .listRowBackground(Theme.Palette.surface)
    }

    @ViewBuilder
    private var claimsSection: some View {
        let claims = user.customClaims
        Section("Custom claims • \(claims.count)") {
            if claims.isEmpty {
                Text("No custom claims set.").foregroundStyle(Theme.Palette.textSecondary)
            } else {
                ForEach(claims, id: \.key) { claim in
                    HStack(alignment: .top) {
                        Text(claim.key).font(.pcMonoSmall).foregroundStyle(Theme.Palette.textPrimary)
                        Spacer()
                        Text(claim.value)
                            .font(.pcMonoSmall)
                            .foregroundStyle(Theme.Palette.textSecondary)
                            .multilineTextAlignment(.trailing)
                            .textSelection(.enabled)
                    }
                }
            }
        }
        .listRowBackground(Theme.Palette.surface)
    }

    private var managementSection: some View {
        Section {
            CardUnavailableNote(
                message: gateMessage,
                systemImage: gateSymbol
            )
        } header: {
            Text("Management")
        } footer: {
            Text("Disable, delete, password reset, session revocation, and claim editing will appear here once verified against a non-production project.")
        }
        .listRowBackground(Theme.Palette.surface)
    }

    // MARK: Helpers

    private var verifiedText: String {
        guard user.email != nil else { return "N/A" }
        return user.emailVerified == true ? "Yes" : "No"
    }

    private var gateMessage: String {
        if env.selectedProjectEnvironment.isProduction {
            return "This is a production project. User management requires unlocking write access with \(env.safeMode.biometryName) each session."
        } else if !env.featureGate.canOfferWrites {
            return "Managing users is a Pro feature. Free access is read-only."
        }
        return "User management actions are read-only in this build."
    }

    private var gateSymbol: String {
        if env.selectedProjectEnvironment.isProduction { return "lock.shield" }
        if !env.featureGate.canOfferWrites { return "star.circle" }
        return "eye"
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(label).foregroundStyle(Theme.Palette.textSecondary)
            Spacer()
            Text(value)
                .foregroundStyle(Theme.Palette.textPrimary)
                .multilineTextAlignment(.trailing)
                .textSelection(.enabled)
        }
    }

    private func copyableRow(_ label: String, _ value: String, mono: Bool = false) -> some View {
        HStack(alignment: .top) {
            Text(label).foregroundStyle(Theme.Palette.textSecondary)
            Spacer()
            Text(value)
                .font(mono ? .pcMonoSmall : .body)
                .foregroundStyle(Theme.Palette.textPrimary)
                .multilineTextAlignment(.trailing)
                .textSelection(.enabled)
        }
        .contextMenu {
            Button {
                UIPasteboard.general.string = value
            } label: {
                Label("Copy \(label)", systemImage: "doc.on.doc")
            }
        }
    }

    private func timeRow(_ label: String, _ date: Date?) -> some View {
        HStack {
            Text(label).foregroundStyle(Theme.Palette.textSecondary)
            Spacer()
            Text(date.map { $0.formatted(date: .abbreviated, time: .shortened) } ?? "—")
                .font(.pcBodyEmphasis)
                .foregroundStyle(Theme.Palette.textPrimary)
        }
    }
}
