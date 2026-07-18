import SwiftUI
import UIKit

struct AuthUserDetailView: View {
    let project: FirebaseProject
    let user: AuthUser
    @Environment(AppEnvironment.self) private var env
    @State private var current: AuthUser
    @State private var showDelete = false
    @State private var showEditClaims = false
    @State private var showClaimsConfirm = false
    @State private var showPasswordReset = false
    @State private var claimsDraft = ""
    @State private var claimsValidationMessage: String?
    @State private var statusMessage: String?
    @State private var busy = false
    @Environment(\.dismiss) private var dismiss

    init(project: FirebaseProject, user: AuthUser) {
        self.project = project
        self.user = user
        _current = State(initialValue: user)
        _claimsDraft = State(initialValue: user.customClaimsJSON)
    }

    var body: some View {
        List {
            identitySection
            statusSection
            if !(current.providerUserInfo ?? []).isEmpty { providersSection }
            timestampsSection
            claimsSection
            managementSection
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .appBackground()
        .navigationTitle(current.primaryLabel)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showDelete) {
            TypedConfirmationSheet(
                title: "Delete user",
                message: "Permanently delete Auth user \(current.localId) in \(project.projectId). Passwords are never shown or recovered by FireTap.",
                confirmPhrase: current.localId,
                confirmButtonTitle: "Delete user",
                isProduction: env.selectedProjectEnvironment.isProduction
            ) {
                Task { await deleteUser() }
            } onCancel: {}
        }
        .sheet(isPresented: $showEditClaims) {
            claimsEditorSheet
        }
        .sheet(isPresented: $showClaimsConfirm) {
            NavigationStack {
                List {
                    Section("Before / after") {
                        Text(claimsDiffSummary)
                            .font(.pcMonoSmall)
                            .textSelection(.enabled)
                    }
                    Section {
                        Text("Custom claims are stored as a JSON object on the user record. FireTap never displays or stores passwords.")
                            .font(.pcCaption)
                            .foregroundStyle(Theme.Palette.textSecondary)
                    }
                }
                .navigationTitle("Confirm claims")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { showClaimsConfirm = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            showClaimsConfirm = false
                            Task { await saveClaims() }
                        }
                        .disabled(busy)
                    }
                }
            }
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showPasswordReset) {
            TypedConfirmationSheet(
                title: "Send password reset",
                message: "Send a password-reset email to \(current.email ?? "this user") via Firebase Authentication. FireTap never displays, generates, or stores passwords.",
                confirmPhrase: current.email ?? current.localId,
                confirmButtonTitle: "Send email",
                isProduction: env.selectedProjectEnvironment.isProduction
            ) {
                Task { await sendPasswordReset() }
            } onCancel: {}
        }
    }

    private var claimsDiffSummary: String {
        AuthUser.claimsDiffSummary(before: current.customAttributes, after: normalizedClaimsDraft ?? claimsDraft)
    }

    private var normalizedClaimsDraft: String? {
        try? AuthUser.normalizedCustomAttributesJSON(claimsDraft)
    }

    private var identitySection: some View {
        Section("Identity") {
            copyableRow("User UID", current.localId, mono: true)
            if let email = current.email { copyableRow("Email", email) }
            if let phone = current.phoneNumber { copyableRow("Phone", phone) }
            if let name = current.displayName, !name.isEmpty { detailRow("Display name", name) }
            if let tenant = current.tenantId { detailRow("Tenant", tenant) }
        }
        .listRowBackground(Theme.Palette.surface)
    }

    private var statusSection: some View {
        Section("Status") {
            HStack {
                Text("Account").foregroundStyle(Theme.Palette.textSecondary)
                Spacer()
                if current.isDisabled {
                    StatusChip(text: "Disabled", systemImage: "nosign",
                               color: Theme.Palette.danger, container: Theme.Palette.dangerContainer)
                } else {
                    StatusChip(text: "Enabled", systemImage: "checkmark.circle.fill")
                }
            }
            HStack {
                Text("Email verified").foregroundStyle(Theme.Palette.textSecondary)
                Spacer()
                Text(current.email == nil ? "N/A" : (current.emailVerified == true ? "Yes" : "No"))
                    .font(.pcBodyEmphasis)
            }
        }
        .listRowBackground(Theme.Palette.surface)
    }

    private var providersSection: some View {
        Section("Sign-in providers") {
            ForEach(current.providerUserInfo ?? []) { provider in
                VStack(alignment: .leading, spacing: 2) {
                    Text(AuthUser.friendlyProvider(provider.providerId ?? "unknown"))
                        .font(.pcBodyEmphasis)
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
            timeRow("Created", current.createdDate)
            timeRow("Last sign-in", current.lastSignInDate)
            timeRow("Last token refresh", current.lastRefreshDate)
        }
        .listRowBackground(Theme.Palette.surface)
    }

    private var claimsSection: some View {
        let claims = current.customClaims
        return Section("Custom claims • \(claims.count)") {
            if claims.isEmpty {
                Text("No custom claims set.").foregroundStyle(Theme.Palette.textSecondary)
            } else {
                ForEach(claims, id: \.key) { claim in
                    HStack {
                        Text(claim.key).font(.pcMonoSmall)
                        Spacer()
                        Text(claim.value).font(.pcMonoSmall).foregroundStyle(Theme.Palette.textSecondary)
                    }
                }
            }
            if let gate = WriteGate.message(env: env) {
                CardUnavailableNote(message: gate.text, systemImage: gate.symbol)
                if env.featureGate.canOfferWrites && !env.safeMode.isWriteUnlocked {
                    Button("Unlock with \(env.safeMode.biometryName)") {
                        Task { _ = await env.safeMode.requestWriteUnlock(reason: "Edit Authentication claims") }
                    }
                }
            } else {
                Button("Edit claims…") {
                    claimsDraft = current.customClaimsJSON
                    claimsValidationMessage = nil
                    showEditClaims = true
                }
                .disabled(busy)
            }
        }
        .listRowBackground(Theme.Palette.surface)
    }

    private var claimsEditorSheet: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Edit the JSON object of custom claims. Changes require review and typed confirmation in production.")
                        .font(.pcCaption)
                        .foregroundStyle(Theme.Palette.textSecondary)
                }
                Section("Claims JSON") {
                    TextEditor(text: $claimsDraft)
                        .font(.pcMonoSmall)
                        .frame(minHeight: 180)
                }
                if let claimsValidationMessage {
                    Section {
                        Text(claimsValidationMessage)
                            .foregroundStyle(Theme.Palette.danger)
                            .font(.pcCaption)
                    }
                }
            }
            .navigationTitle("Edit claims")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showEditClaims = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Review") {
                        validateAndReviewClaims()
                    }
                    .disabled(busy)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var managementSection: some View {
        Section {
            if let gate = WriteGate.message(env: env) {
                CardUnavailableNote(message: gate.text, systemImage: gate.symbol)
                if env.featureGate.canOfferWrites && !env.safeMode.isWriteUnlocked {
                    Button("Unlock with \(env.safeMode.biometryName)") {
                        Task { _ = await env.safeMode.requestWriteUnlock(reason: "Manage Authentication users") }
                    }
                }
            } else {
                Button(current.isDisabled ? "Enable user" : "Disable user") {
                    Task { await setDisabled(!current.isDisabled) }
                }
                .disabled(busy)
                if let email = current.email, !email.isEmpty {
                    Button("Send password reset email…") {
                        showPasswordReset = true
                    }
                    .disabled(busy)
                }
                Button("Delete user…", role: .destructive) { showDelete = true }
                    .disabled(busy)
            }
            if let statusMessage {
                Text(statusMessage).font(.pcCaption).foregroundStyle(Theme.Palette.textSecondary)
            }
        } header: {
            Text("Management")
        } footer: {
            Text("FireTap never displays, requests, recovers, or stores user passwords.")
        }
        .listRowBackground(Theme.Palette.surface)
    }

    private func validateAndReviewClaims() {
        do {
            _ = try AuthUser.normalizedCustomAttributesJSON(claimsDraft)
            claimsValidationMessage = nil
            showEditClaims = false
            showClaimsConfirm = true
        } catch let error as AuthClaimsValidationError {
            claimsValidationMessage = error.userMessage
        } catch {
            claimsValidationMessage = AuthClaimsValidationError.invalidJSON.userMessage
        }
    }

    private func saveClaims() async {
        guard await WriteGate.ensureUnlocked(env: env, reason: "Update Authentication claims") else { return }
        guard let normalized = normalizedClaimsDraft else {
            statusMessage = AuthClaimsValidationError.invalidJSON.userMessage
            return
        }
        busy = true
        defer { busy = false }
        let beforeClaims = current.customAttributes
        do {
            let updated = try await env.authService.updateUser(
                projectID: project.projectId,
                request: AuthUserUpdateRequest(localId: current.localId, customAttributes: normalized)
            )
            current = updated
            claimsDraft = updated.customClaimsJSON
            statusMessage = "Custom claims updated."
            await env.audit.record(AuditEntry(
                accountID: env.accountManager.activeAccountID,
                projectID: project.projectId,
                action: "auth.claims_update",
                resource: current.localId,
                summary: "Updated custom claims",
                reversible: true,
                beforeValue: beforeClaims,
                afterValue: normalized
            ))
        } catch let error as APIError {
            statusMessage = error.userMessage
        } catch {
            statusMessage = "Claims update failed."
        }
    }

    private func sendPasswordReset() async {
        guard let email = current.email, !email.isEmpty else { return }
        guard await WriteGate.ensureUnlocked(env: env, reason: "Send password reset email") else { return }
        busy = true
        defer { busy = false }
        do {
            try await env.authService.sendPasswordResetEmail(projectID: project.projectId, email: email)
            statusMessage = "Password reset email sent to \(email)."
            await env.audit.record(AuditEntry(
                accountID: env.accountManager.activeAccountID,
                projectID: project.projectId,
                action: "auth.password_reset",
                resource: current.localId,
                summary: "Sent password reset email",
                reversible: false
            ))
        } catch let error as APIError {
            statusMessage = error.userMessage
        } catch {
            statusMessage = "Password reset email failed."
        }
    }

    private func setDisabled(_ disabled: Bool) async {
        guard await WriteGate.ensureUnlocked(env: env, reason: "Update Authentication user") else { return }
        busy = true
        defer { busy = false }
        do {
            let updated = try await env.authService.updateUser(
                projectID: project.projectId,
                request: AuthUserUpdateRequest(localId: current.localId, disableUser: disabled)
            )
            current = updated
            statusMessage = disabled ? "User disabled." : "User enabled."
            await env.audit.record(AuditEntry(
                accountID: env.accountManager.activeAccountID,
                projectID: project.projectId,
                action: disabled ? "auth.disable" : "auth.enable",
                resource: current.localId,
                summary: disabled ? "Disabled user" : "Enabled user",
                reversible: true
            ))
        } catch let error as APIError {
            statusMessage = error.userMessage
        } catch {
            statusMessage = "Update failed."
        }
    }

    private func deleteUser() async {
        guard await WriteGate.ensureUnlocked(env: env, reason: "Delete Authentication user") else { return }
        busy = true
        defer { busy = false }
        do {
            try await env.authService.deleteUser(projectID: project.projectId, localID: current.localId)
            await env.audit.record(AuditEntry(
                accountID: env.accountManager.activeAccountID,
                projectID: project.projectId,
                action: "auth.delete",
                resource: current.localId,
                summary: "Deleted user",
                reversible: false
            ))
            dismiss()
        } catch let error as APIError {
            statusMessage = error.userMessage
        } catch {
            statusMessage = "Delete failed."
        }
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(label).foregroundStyle(Theme.Palette.textSecondary)
            Spacer()
            Text(value).multilineTextAlignment(.trailing).textSelection(.enabled)
        }
    }

    private func copyableRow(_ label: String, _ value: String, mono: Bool = false) -> some View {
        HStack(alignment: .top) {
            Text(label).foregroundStyle(Theme.Palette.textSecondary)
            Spacer()
            Text(value).font(mono ? .pcMonoSmall : .body).multilineTextAlignment(.trailing).textSelection(.enabled)
        }
        .contextMenu {
            Button { UIPasteboard.general.string = value } label: {
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
        }
    }
}
