import SwiftUI

struct FunctionDetailView: View {
    let project: FirebaseProject
    let function: CloudFunctionSummary

    @Environment(AppEnvironment.self) private var env
    @State private var endpointText = ""
    @State private var httpMethod: HTTPRequest.Method = .get
    @State private var requestBody = ""
    @State private var includeAuth = true
    @State private var invokePhase: AsyncPhase<FunctionHTTPInvokeResult> = .idle
    @State private var sending = false

    private var accountID: String { env.accountManager.activeAccountID ?? "anonymous" }
    private var resourceKey: String { ResourceKey.function(function.name) }
    private var knownURL: URL? { function.url.flatMap(URL.init(string:)) }
    private var endpointURL: URL? { URL(string: endpointText.trimmingCharacters(in: .whitespacesAndNewlines)) }
    private var endpointEditedFromKnown: Bool {
        guard let knownURL, let endpointURL else { return false }
        return endpointURL.absoluteString != knownURL.absoluteString
    }
    private var canSend: Bool {
        guard endpointURL != nil else { return false }
        if let knownURL {
            return endpointURL?.absoluteString == knownURL.absoluteString
        }
        return false
    }

    var body: some View {
        List {
            metadataSection
            if function.url != nil {
                invokeSection
                requestPreviewSection
            }
            if case .failed(let error) = invokePhase {
                Section {
                    Text(error.userMessage)
                        .foregroundStyle(Theme.Palette.danger)
                }
                .listRowBackground(Theme.Palette.surface)
            }
            if let result = invokePhase.value {
                responseSection(result)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .appBackground()
        .navigationTitle(function.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if endpointText.isEmpty, let url = function.url {
                endpointText = url
            }
            env.preferences.recordRecentlyViewed(resourceKey, account: accountID)
        }
    }

    private var metadataSection: some View {
        Section("Function") {
            detailRow("Environment", function.environment)
            detailRow("Region", function.region ?? "—")
            detailRow("Runtime", function.runtime ?? "—")
            detailRow("Trigger", function.trigger ?? "—")
            if let url = function.url {
                detailRow("HTTPS URL", url, mono: true)
            }
            detailRow("Status", function.status ?? "—")
            if let updateTime = function.updateTime {
                detailRow("Updated", updateTime)
            }
        }
        .listRowBackground(Theme.Palette.surface)
    }

    private var invokeSection: some View {
        Section {
            TextField("Endpoint URL", text: $endpointText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.pcMonoSmall)

            if endpointEditedFromKnown {
                Label(
                    "This URL differs from the function URL returned by the API. Invoking edited URLs is blocked for safety.",
                    systemImage: "exclamationmark.triangle.fill"
                )
                .font(.pcCaption)
                .foregroundStyle(Theme.Palette.warning)
            }

            Picker("Method", selection: $httpMethod) {
                Text("GET").tag(HTTPRequest.Method.get)
                Text("POST").tag(HTTPRequest.Method.post)
            }
            .pickerStyle(.segmented)

            if httpMethod == .post {
                TextEditor(text: $requestBody)
                    .font(.pcMonoSmall)
                    .frame(minHeight: 120)
            }

            if isGoogleHosted(endpointURL) {
                Toggle("Attach Google bearer token", isOn: $includeAuth)
            }

            if let gate = WriteGate.message(env: env) {
                CardUnavailableNote(message: gate.text, systemImage: gate.symbol)
            }

            Button(sending ? "Sending…" : "Send request") {
                Task { await sendRequest() }
            }
            .disabled(sending || !canSend || WriteGate.message(env: env) != nil)

            if function.url == nil {
                Text("This function has no HTTPS URL from the API. HTTP invoke is only available when the function exposes a known HTTPS endpoint.")
                    .font(.pcCaption)
                    .foregroundStyle(Theme.Palette.textSecondary)
            }
        } header: {
            Text("HTTP invoke")
        } footer: {
            Text("Requests are never sent automatically. FireTap only invokes the exact HTTPS URL returned for this function. Optional JSON body is sent only for POST.")
        }
        .listRowBackground(Theme.Palette.surface)
    }

    private var requestPreviewSection: some View {
        Section("Request preview") {
            Text(requestPreview)
                .font(.pcMonoSmall)
                .textSelection(.enabled)
        }
        .listRowBackground(Theme.Palette.surface)
    }
    private func responseSection(_ result: FunctionHTTPInvokeResult) -> some View {
        Section("Response • HTTP \(result.status)") {
            Text(result.body)
                .font(.pcMonoSmall)
                .textSelection(.enabled)
        }
        .listRowBackground(Theme.Palette.surface)
    }

    private var requestPreview: String {
        var lines = ["\(httpMethod.rawValue) \(endpointText.trimmingCharacters(in: .whitespacesAndNewlines))"]
        if httpMethod == .post, !requestBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            lines.append("Content-Type: application/json")
            lines.append("")
            lines.append(requestBody)
        }
        if includeAuth, isGoogleHosted(endpointURL) {
            lines.append("")
            lines.append("Authorization: Bearer …")
        }
        return lines.joined(separator: "\n")
    }

    private func detailRow(_ label: String, _ value: String, mono: Bool = false) -> some View {
        LabeledContent(label) {
            Text(value)
                .font(mono ? .pcMonoSmall : .pcBody)
                .multilineTextAlignment(.trailing)
                .textSelection(.enabled)
        }
    }

    private func isGoogleHosted(_ url: URL?) -> Bool {
        guard let host = url?.host?.lowercased() else { return false }
        return host.contains("googleapis.com")
            || host.contains("cloudfunctions.net")
            || host.hasSuffix(".run.app")
            || host.hasSuffix(".functions.firebase.com")
    }

    private func sendRequest() async {
        guard let url = endpointURL, canSend else { return }
        guard await WriteGate.ensureUnlocked(env: env, reason: "Invoke Cloud Function over HTTP") else { return }

        sending = true
        invokePhase = .loading
        defer { sending = false }

        let bodyData: Data?
        if httpMethod == .post {
            let trimmed = requestBody.trimmingCharacters(in: .whitespacesAndNewlines)
            bodyData = trimmed.isEmpty ? nil : trimmed.data(using: .utf8)
        } else {
            bodyData = nil
        }

        let attachAuth = includeAuth && isGoogleHosted(url)
        do {
            let result = try await env.functionsService.invokeHTTP(
                url: url,
                method: httpMethod,
                headers: bodyData == nil ? [:] : ["Content-Type": "application/json"],
                body: bodyData,
                attachBearer: attachAuth
            )
            invokePhase = .loaded(result)
            await env.audit.record(AuditEntry(
                accountID: env.accountManager.activeAccountID,
                projectID: project.projectId,
                action: "functions.http_invoke",
                resource: function.name,
                summary: "Invoked \(function.displayName) (\(result.status))",
                reversible: false
            ))
        } catch let error as APIError {
            invokePhase = .failed(error)
        } catch {
            invokePhase = .failed(.transport(underlying: "unknown"))
        }
    }
}
