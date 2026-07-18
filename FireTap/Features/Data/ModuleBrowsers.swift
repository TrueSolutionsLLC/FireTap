import SwiftUI

struct FunctionsBrowserView: View {
    let project: FirebaseProject
    @Environment(AppEnvironment.self) private var env

    var body: some View {
        LiveServiceListView(
            title: "Cloud Functions",
            symbol: "bolt.fill",
            emptyTitle: "No functions",
            emptyMessage: "No Gen1 or Gen2 functions were returned for this project, or the Cloud Functions API isn’t enabled.",
            load: { try await env.functionsService.listFunctions(projectID: project.projectId) }
        ) { function in
            NavigationLink {
                FunctionDetailView(project: project, function: function)
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(function.displayName).font(.pcBodyEmphasis)
                    Text("\(function.environment) · \(function.region ?? "—") · \(function.runtime ?? "—")")
                        .font(.pcCaption)
                        .foregroundStyle(Theme.Palette.textSecondary)
                    Text("\(function.trigger ?? "trigger?") · \(function.status ?? "status?")")
                        .font(.pcCaption)
                        .foregroundStyle(Theme.Palette.textTertiary)
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    MonitoringMetricsView(project: project)
                } label: {
                    Label("Metrics", systemImage: "chart.line.uptrend.xyaxis")
                }
            }
        }
    }
}

struct LogsBrowserView: View {
    let project: FirebaseProject
    @Environment(AppEnvironment.self) private var env
    @State private var phase: AsyncPhase<[LogEntry]> = .idle
    @State private var severity = "ERROR"
    @State private var expandedGroups: Set<String> = []
    @State private var expandedPayloads: Set<String> = []

    private var groups: [LogEntryGroup] {
        guard let entries = phase.value else { return [] }
        return LogEntryGroup.group(entries)
    }

    var body: some View {
        Group {
            switch phase {
            case .idle, .loading:
                LoadingStateView().padding()
            case .failed(let error):
                ErrorStateView(error: error) { Task { await load() } }
            case .loaded(let entries):
                List {
                    Section {
                        Picker("Minimum severity", selection: $severity) {
                            Text("ERROR").tag("ERROR")
                            Text("WARNING").tag("WARNING")
                            Text("INFO").tag("INFO")
                        }
                        .onChange(of: severity) { _, _ in Task { await load() } }
                    }
                    Section("Groups • \(groups.count) · \(entries.count) entries") {
                        if entries.isEmpty {
                            Text("No log entries matched this filter.")
                                .foregroundStyle(Theme.Palette.textSecondary)
                        }
                        ForEach(groups) { group in
                            if group.count == 1 {
                                singleEntryRow(group.representative)
                            } else {
                                DisclosureGroup(
                                    isExpanded: Binding(
                                        get: { expandedGroups.contains(group.id) },
                                        set: { isExpanded in
                                            if isExpanded { expandedGroups.insert(group.id) }
                                            else { expandedGroups.remove(group.id) }
                                        }
                                    )
                                ) {
                                    ForEach(group.entries) { entry in
                                        logEntrySection(entry, nested: true)
                                    }
                                } label: {
                                    logEntryHeader(group.representative, count: group.count)
                                }
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .refreshable { await load() }
            }
        }
        .appBackground()
        .navigationTitle("Logs")
        .task { if phase.value == nil { await load() } }
    }

    @ViewBuilder
    private func singleEntryRow(_ entry: LogEntry) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            logEntryHeader(entry, count: nil)
            jsonPayloadDisclosure(entry)
        }
        .listRowBackground(Theme.Palette.surface)
    }

    @ViewBuilder
    private func logEntrySection(_ entry: LogEntry, nested: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if nested {
                logEntryHeader(entry, count: nil)
            }
            jsonPayloadDisclosure(entry)
        }
        .listRowBackground(Theme.Palette.surface)
    }

    @ViewBuilder
    private func jsonPayloadDisclosure(_ entry: LogEntry) -> some View {
        if let json = entry.jsonPayloadText {
            DisclosureGroup(
                isExpanded: Binding(
                    get: { expandedPayloads.contains(entry.id) },
                    set: { isExpanded in
                        if isExpanded { expandedPayloads.insert(entry.id) }
                        else { expandedPayloads.remove(entry.id) }
                    }
                )
            ) {
                Text(json)
                    .font(.pcMonoSmall)
                    .textSelection(.enabled)
            } label: {
                Text("Structured jsonPayload")
                    .font(.pcCaption)
                    .foregroundStyle(Theme.Palette.info)
            }
        }
    }

    private func logEntryHeader(_ entry: LogEntry, count: Int?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(entry.severity ?? "DEFAULT")
                    .font(.pcLabel)
                    .foregroundStyle(Theme.Palette.warning)
                Spacer()
                if let count, count > 1 {
                    Text("\(count)")
                        .font(.pcLabel)
                        .foregroundStyle(Theme.Palette.accent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Theme.Palette.surfaceRaised, in: Capsule())
                }
            }
            Text(entry.displaySummary)
                .font(.pcMonoSmall)
                .lineLimit(4)
            if let ts = entry.timestamp {
                Text(ts).font(.pcCaption).foregroundStyle(Theme.Palette.textTertiary)
            }
        }
    }

    private func load() async {
        if phase.value == nil { phase = .loading }
        do {
            let filter = LoggingFilter.build(severityAtLeast: severity)
            let response = try await env.loggingService.listEntries(
                projectID: project.projectId,
                filter: filter,
                pageSize: 50,
                pageToken: nil
            )
            expandedGroups = []
            expandedPayloads = []
            phase = .loaded(response.entries)
        } catch let error as APIError {
            phase = .failed(error)
        } catch {
            phase = .failed(.transport(underlying: "unknown"))
        }
    }
}

struct RealtimeDatabaseBrowserView: View {
    let project: FirebaseProject
    @Environment(AppEnvironment.self) private var env

    var body: some View {
        Group {
            if let instance = project.resources?.realtimeDatabaseInstance, !instance.isEmpty,
               let url = RealtimeDatabaseURL.fromInstanceName(instance) {
                RealtimeDatabasePathView(project: project, databaseURL: url, path: "")
            } else if let number = project.projectNumber {
                LiveServiceListView(
                    title: "Realtime Database",
                    symbol: "point.3.connected.trianglepath.dotted",
                    emptyTitle: "No instances",
                    emptyMessage: "No Realtime Database instances were listed for this project.",
                    load: { try await env.realtimeDatabaseService.listInstances(projectNumber: number) }
                ) { instance in
                    NavigationLink {
                        if let url = instance.databaseURL
                            ?? instance.name.flatMap({ RealtimeDatabaseURL.fromInstanceName($0.split(separator: "/").last.map(String.init) ?? $0) })
                        {
                            RealtimeDatabasePathView(project: project, databaseURL: url, path: "")
                        } else {
                            Text("Missing database URL")
                        }
                    } label: {
                        Text(instance.name?.split(separator: "/").last.map(String.init) ?? instance.id)
                            .font(.pcBodyEmphasis)
                    }
                }
            } else {
                EmptyStateView(
                    title: "No Realtime Database",
                    message: "This Firebase project has no realtimeDatabaseInstance resource and no project number for instance listing.",
                    systemImage: "point.3.connected.trianglepath.dotted"
                )
                .navigationTitle("Realtime Database")
            }
        }
    }
}

struct RealtimeDatabasePathView: View {
    let project: FirebaseProject
    let databaseURL: URL
    let path: String
    @Environment(AppEnvironment.self) private var env
    @State private var model: RealtimeDatabasePathViewModel?
    @State private var showDeleteConfirm = false
    @State private var showCreateChild = false
    @State private var didDelete = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Group {
            if let model {
                content(model)
            } else {
                LoadingStateView().padding()
            }
        }
        .appBackground()
        .navigationTitle(path.isEmpty ? "Root" : path.split(separator: "/").last.map(String.init) ?? path)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if model == nil {
                let vm = RealtimeDatabasePathViewModel(
                    projectID: project.projectId,
                    databaseURL: databaseURL,
                    path: path,
                    service: env.realtimeDatabaseService,
                    audit: env.audit
                )
                model = vm
                await vm.load(forceFullDepth: !path.isEmpty)
            }
        }
        .onChange(of: didDelete) { _, deleted in
            if deleted { dismiss() }
        }
        .sheet(isPresented: $showDeleteConfirm) {
            TypedConfirmationSheet(
                title: "Delete node",
                message: "Permanently delete RTDB node \(displayPath) in \(project.projectId). Child data is removed with the node.",
                confirmPhrase: deleteConfirmPhrase,
                confirmButtonTitle: "Delete node",
                isProduction: env.selectedProjectEnvironment.isProduction
            ) {
                Task {
                    guard await WriteGate.ensureUnlocked(env: env, reason: "Delete Realtime Database node") else { return }
                    if await model?.deleteNode() == true { didDelete = true }
                }
            } onCancel: {}
        }
        .sheet(isPresented: $showCreateChild) {
            createChildSheet
        }
    }

    private var displayPath: String {
        path.isEmpty ? "/" : "/\(path)"
    }

    private var deleteConfirmPhrase: String {
        path.split(separator: "/").last.map(String.init) ?? "root"
    }

    @ViewBuilder
    private func content(_ model: RealtimeDatabasePathViewModel) -> some View {
        @Bindable var model = model
        if model.isLoading && model.snapshot == nil {
            LoadingStateView().padding()
        } else if let error = model.error, model.snapshot == nil {
            ErrorStateView(error: error) { Task { await model.load(forceFullDepth: !path.isEmpty) } }
        } else {
            List {
                if let warning = model.largeReadWarning {
                    Section {
                        Label(warning, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(Theme.Palette.warning)
                            .font(.pcCaption)
                    }
                    .listRowBackground(Theme.Palette.surface)
                }

                if let error = model.error {
                    Section {
                        Text(error.userMessage)
                            .foregroundStyle(Theme.Palette.danger)
                        if model.conflictDetected {
                            Button("Reload node") {
                                Task { await model.load(forceFullDepth: true) }
                            }
                        }
                    }
                    .listRowBackground(Theme.Palette.surface)
                }

                if !model.childKeys.isEmpty {
                    Section("Children • \(model.childKeys.count)") {
                        ForEach(model.childKeys, id: \.self) { key in
                            NavigationLink {
                                RealtimeDatabasePathView(
                                    project: project,
                                    databaseURL: databaseURL,
                                    path: model.childPath(for: key)
                                )
                            } label: {
                                Text(key).font(.pcBodyEmphasis)
                            }
                            .listRowBackground(Theme.Palette.surface)
                        }
                    }
                }

                Section(model.isEditing ? "Edit JSON" : "JSON") {
                    if model.isEditing && WriteGate.message(env: env) == nil {
                        TextEditor(text: $model.draftJSON)
                            .font(.pcMonoSmall)
                            .frame(minHeight: 220)
                    } else if let snapshot = model.snapshot {
                        Text(snapshot.text)
                            .font(.pcMonoSmall)
                            .textSelection(.enabled)
                    } else {
                        Text("null").foregroundStyle(Theme.Palette.textSecondary)
                    }
                }
                .listRowBackground(Theme.Palette.surface)

                writeSection(model)
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .refreshable { await model.load(forceFullDepth: true) }
        }
    }

    @ViewBuilder
    private func writeSection(_ model: RealtimeDatabasePathViewModel) -> some View {
        Section {
            if let gate = WriteGate.message(env: env) {
                CardUnavailableNote(message: gate.text, systemImage: gate.symbol)
                if env.featureGate.canOfferWrites && !env.safeMode.isWriteUnlocked {
                    Button("Unlock with \(env.safeMode.biometryName)") {
                        Task { _ = await env.safeMode.requestWriteUnlock(reason: "Edit Realtime Database") }
                    }
                }
            } else {
                if model.isEditing {
                    Button(model.isSaving ? "Saving…" : "Save changes") {
                        Task {
                            guard await WriteGate.ensureUnlocked(env: env, reason: "Save Realtime Database node") else { return }
                            _ = await model.save()
                        }
                    }
                    .disabled(model.isSaving || !model.hasDraftChanges)
                    Button("Cancel editing") { model.cancelEditing() }
                        .disabled(model.isSaving)
                } else {
                    Button("Edit JSON…") {
                        Task {
                            await model.load(forceFullDepth: true)
                            model.beginEditing()
                        }
                    }
                    .disabled(!model.canEdit)
                    Button("Create child node…") { showCreateChild = true }
                    Button("Delete node…", role: .destructive) { showDeleteConfirm = true }
                        .disabled(model.isDeleting)
                }
            }
        } header: {
            Text("Write")
        } footer: {
            Text("Writes use If-Match ETags from the last GET. Concurrent edits return a conflict you can resolve by reloading.")
        }
        .listRowBackground(Theme.Palette.surface)
    }

    private var createChildSheet: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Creates a child at /\(path.isEmpty ? "{key}" : "\(path)/{key}") using PUT.")
                        .font(.pcCaption)
                        .foregroundStyle(Theme.Palette.textSecondary)
                }
                Section("Child key") {
                    TextField("Key name", text: Binding(
                        get: { model?.newChildKey ?? "" },
                        set: { model?.newChildKey = $0 }
                    ))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                }
                Section("Initial JSON value") {
                    TextEditor(text: Binding(
                        get: { model?.newChildJSON ?? "null" },
                        set: { model?.newChildJSON = $0 }
                    ))
                    .font(.pcMonoSmall)
                    .frame(minHeight: 120)
                }
            }
            .navigationTitle("Create child")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showCreateChild = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        showCreateChild = false
                        Task {
                            guard await WriteGate.ensureUnlocked(env: env, reason: "Create Realtime Database child") else { return }
                            _ = await model?.createChild()
                        }
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

struct RemoteConfigBrowserView: View {
    let project: FirebaseProject
    @Environment(AppEnvironment.self) private var env
    @State private var phase: AsyncPhase<RemoteConfigBrowserSnapshot> = .idle
    @State private var versionsPhase: AsyncPhase<[RemoteConfigVersion]> = .idle
    @State private var statusMessage: String?
    @State private var publishing = false
    @State private var rollbackTarget: RemoteConfigVersion?
    @State private var showRollbackConfirm = false

    var body: some View {
        Group {
            switch phase {
            case .idle, .loading:
                LoadingStateView().padding()
            case .failed(let error):
                ErrorStateView(error: error) { Task { await load() } }
            case .loaded(let snapshot):
                let params = snapshot.template.parameters ?? [:]
                List {
                    Section("ETag") {
                        Text(snapshot.etag ?? "—")
                            .font(.pcMonoSmall)
                            .textSelection(.enabled)
                    }

                    Section {
                        if let gate = WriteGate.message(env: env) {
                            CardUnavailableNote(message: gate.text, systemImage: gate.symbol)
                        }
                        Button(publishing ? "Publishing…" : "Publish current template") {
                            Task { await publish(snapshot: snapshot) }
                        }
                        .disabled(publishing || snapshot.etag == nil || WriteGate.message(env: env) != nil)
                        if let statusMessage {
                            Text(statusMessage)
                                .font(.pcCaption)
                                .foregroundStyle(Theme.Palette.textSecondary)
                        }
                    } footer: {
                        Text("Publish sends the loaded template with If-Match ETag precondition. Reload before publishing if the template changed elsewhere.")
                    }

                    Section("Parameters • \(params.count)") {
                        if params.isEmpty {
                            Text("No parameters in the current template.")
                                .foregroundStyle(Theme.Palette.textSecondary)
                        }
                        ForEach(params.keys.sorted(), id: \.self) { key in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(key).font(.pcBodyEmphasis)
                                Text(params[key]?.defaultValue?.value ?? "(no default)")
                                    .font(.pcMonoSmall)
                                    .foregroundStyle(Theme.Palette.textSecondary)
                            }
                            .listRowBackground(Theme.Palette.surface)
                        }
                    }

                    versionsSection
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .refreshable { await load() }
            }
        }
        .appBackground()
        .navigationTitle("Remote Config")
        .task {
            if phase.value == nil { await load() }
            if versionsPhase.value == nil { await loadVersions() }
        }
        .sheet(isPresented: $showRollbackConfirm) {
            if let rollbackTarget {
                TypedConfirmationSheet(
                    title: "Rollback Remote Config",
                    message: "Rollback replaces the live template with version \(rollbackTarget.versionNumber ?? "?"). This affects all clients fetching Remote Config.",
                    confirmPhrase: rollbackTarget.versionNumber ?? "",
                    confirmButtonTitle: "Rollback",
                    isProduction: env.selectedProjectEnvironment.isProduction,
                    onConfirm: { Task { await performRollback(rollbackTarget) } },
                    onCancel: { self.rollbackTarget = nil }
                )
            }
        }
    }

    @ViewBuilder
    private var versionsSection: some View {
        Section("Version history") {
            switch versionsPhase {
            case .idle, .loading:
                ProgressView().listRowBackground(Theme.Palette.surface)
            case .failed(let error):
                Text(error.userMessage)
                    .font(.pcCaption)
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .listRowBackground(Theme.Palette.surface)
            case .loaded(let versions):
                if versions.isEmpty {
                    Text("No prior versions returned.")
                        .foregroundStyle(Theme.Palette.textSecondary)
                        .listRowBackground(Theme.Palette.surface)
                }
                ForEach(versions) { version in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("v\(version.versionNumber ?? "?")")
                                .font(.pcBodyEmphasis)
                            if let updateTime = version.updateTime {
                                Text(updateTime)
                                    .font(.pcCaption)
                                    .foregroundStyle(Theme.Palette.textSecondary)
                            }
                            if let description = version.description, !description.isEmpty {
                                Text(description)
                                    .font(.pcCaption)
                                    .foregroundStyle(Theme.Palette.textTertiary)
                                    .lineLimit(2)
                            }
                        }
                        Spacer()
                        if version.versionNumber != nil, WriteGate.message(env: env) == nil {
                            Button("Rollback") {
                                rollbackTarget = version
                                showRollbackConfirm = true
                            }
                            .font(.pcCaption)
                        }
                    }
                    .listRowBackground(Theme.Palette.surface)
                }
            }
        }
    }

    private func load() async {
        if phase.value == nil { phase = .loading }
        do {
            let result = try await env.remoteConfigService.getTemplate(projectID: project.projectId)
            phase = .loaded(RemoteConfigBrowserSnapshot(template: result.template, etag: result.etag))
        } catch let error as APIError {
            phase = .failed(error)
        } catch {
            phase = .failed(.transport(underlying: "unknown"))
        }
    }

    private func loadVersions() async {
        if versionsPhase.value == nil { versionsPhase = .loading }
        do {
            let response = try await env.remoteConfigService.listVersions(
                projectID: project.projectId,
                pageSize: 25,
                pageToken: nil
            )
            versionsPhase = .loaded(response.versions ?? [])
        } catch let error as APIError {
            versionsPhase = .failed(error)
        } catch {
            versionsPhase = .failed(.transport(underlying: "unknown"))
        }
    }

    private func publish(snapshot: RemoteConfigBrowserSnapshot) async {
        guard let etag = snapshot.etag else { return }
        guard await WriteGate.ensureUnlocked(env: env, reason: "Publish Remote Config template") else { return }
        publishing = true
        defer { publishing = false }
        do {
            let result = try await env.remoteConfigService.publishTemplate(
                projectID: project.projectId,
                template: snapshot.template,
                ifMatch: etag
            )
            statusMessage = "Published. New ETag: \(result.etag ?? "—")"
            phase = .loaded(RemoteConfigBrowserSnapshot(template: result.template, etag: result.etag))
            await loadVersions()
            await env.audit.record(AuditEntry(
                accountID: env.accountManager.activeAccountID,
                projectID: project.projectId,
                action: "remoteconfig.publish",
                resource: project.projectId,
                summary: "Published Remote Config template",
                reversible: true
            ))
        } catch let error as APIError {
            statusMessage = error.userMessage
        } catch {
            statusMessage = "Publish failed."
        }
    }

    private func performRollback(_ version: RemoteConfigVersion) async {
        guard let number = version.versionNumber else { return }
        guard await WriteGate.ensureUnlocked(env: env, reason: "Rollback Remote Config") else { return }
        do {
            let result = try await env.remoteConfigService.rollback(projectID: project.projectId, versionNumber: number)
            statusMessage = "Rolled back to v\(number)."
            phase = .loaded(RemoteConfigBrowserSnapshot(template: result.template, etag: result.etag))
            await loadVersions()
            await env.audit.record(AuditEntry(
                accountID: env.accountManager.activeAccountID,
                projectID: project.projectId,
                action: "remoteconfig.rollback",
                resource: number,
                summary: "Rolled back Remote Config to v\(number)",
                reversible: true
            ))
        } catch let error as APIError {
            statusMessage = error.userMessage
        } catch {
            statusMessage = "Rollback failed."
        }
        rollbackTarget = nil
    }
}

private struct RemoteConfigBrowserSnapshot: Sendable, Equatable {
    let template: RemoteConfigTemplate
    let etag: String?
}

struct HostingBrowserView: View {
    let project: FirebaseProject
    @Environment(AppEnvironment.self) private var env

    var body: some View {
        LiveServiceListView(
            title: "Hosting",
            symbol: "globe",
            emptyTitle: "No sites",
            emptyMessage: "No Firebase Hosting sites were returned for this project.",
            load: { try await env.hostingService.listSites(projectID: project.projectId) }
        ) { site in
            NavigationLink {
                HostingSiteDetailView(project: project, site: site)
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(site.siteID).font(.pcBodyEmphasis)
                    if let url = site.defaultUrl {
                        Text(url).font(.pcCaption).foregroundStyle(Theme.Palette.textSecondary).lineLimit(1)
                    }
                }
            }
        }
    }
}

struct AppCheckBrowserView: View {
    let project: FirebaseProject
    @Environment(AppEnvironment.self) private var env

    var body: some View {
        LiveServiceListView(
            title: "App Check",
            symbol: "checkmark.shield.fill",
            emptyTitle: "No service configs",
            emptyMessage: "No App Check service enforcement configs were returned.",
            load: { try await env.appCheckService.listServices(projectID: project.projectId) }
        ) { service in
            VStack(alignment: .leading, spacing: 2) {
                Text(service.serviceID).font(.pcBodyEmphasis)
                Text(service.enforcementMode ?? "enforcement unknown")
                    .font(.pcCaption)
                    .foregroundStyle(Theme.Palette.textSecondary)
            }
        }
    }
}

struct IAMBrowserView: View {
    let project: FirebaseProject
    @Environment(AppEnvironment.self) private var env
    @State private var phase: AsyncPhase<ProjectIAMPolicy> = .idle

    var body: some View {
        Group {
            switch phase {
            case .idle, .loading:
                LoadingStateView().padding()
            case .failed(let error):
                ErrorStateView(error: error) { Task { await load() } }
            case .loaded(let policy):
                let bindings = policy.bindings ?? []
                List {
                    Section {
                        Text("IAM editing is read-only in FireTap 1.0.")
                            .font(.pcCaption)
                            .foregroundStyle(Theme.Palette.textSecondary)
                    }
                    Section("Bindings • \(bindings.count)") {
                        ForEach(bindings) { binding in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(binding.role ?? "role?")
                                    .font(.pcBodyEmphasis)
                                ForEach(binding.members ?? [], id: \.self) { member in
                                    Text(member)
                                        .font(.pcMonoSmall)
                                        .foregroundStyle(Theme.Palette.textSecondary)
                                }
                            }
                            .listRowBackground(Theme.Palette.surface)
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .refreshable { await load() }
            }
        }
        .appBackground()
        .navigationTitle("IAM")
        .task { if phase.value == nil { await load() } }
    }

    private func load() async {
        if phase.value == nil { phase = .loading }
        do {
            phase = .loaded(try await env.iamService.getIamPolicy(projectID: project.projectId))
        } catch let error as APIError {
            phase = .failed(error)
        } catch {
            phase = .failed(.transport(underlying: "unknown"))
        }
    }
}

struct FCMTestMessageView: View {
    let project: FirebaseProject
    @Environment(AppEnvironment.self) private var env
    @State private var token = ""
    @State private var title = "FireTap test"
    @State private var bodyText = "Test notification"
    @State private var preview = false
    @State private var status: String?
    @State private var sending = false

    var body: some View {
        Form {
            Section("Target") {
                TextField("Device registration token", text: $token)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Text("Only a single explicitly entered token is supported. Tokens are not retained unless you copy them yourself.")
                    .font(.pcCaption)
                    .foregroundStyle(Theme.Palette.textSecondary)
            }
            Section("Notification") {
                TextField("Title", text: $title)
                TextField("Body", text: $bodyText)
            }
            Section("Payload preview") {
                Text(payloadJSON)
                    .font(.pcMonoSmall)
                    .textSelection(.enabled)
            }
            Section {
                if let gate = WriteGate.message(env: env) {
                    CardUnavailableNote(message: gate.text, systemImage: gate.symbol)
                }
                Button(sending ? "Sending…" : "Send test message") {
                    Task { await send() }
                }
                .disabled(token.isEmpty || sending || WriteGate.message(env: env) != nil)
                if let status {
                    Text(status).font(.pcCaption).foregroundStyle(Theme.Palette.textSecondary)
                }
            }
        }
        .navigationTitle("Cloud Messaging")
        .appBackground()
    }

    private var payloadJSON: String {
        """
        {
          "token": "\(token.prefix(12))…",
          "notification": { "title": "\(title)", "body": "\(bodyText)" }
        }
        """
    }

    private func send() async {
        guard await WriteGate.ensureUnlocked(env: env, reason: "Send FCM test message") else { return }
        sending = true
        defer { sending = false }
        do {
            let response = try await env.fcmService.sendTestMessage(
                projectID: project.projectId,
                message: FCMMessage(
                    token: token,
                    notification: FCMNotification(title: title, body: bodyText),
                    data: nil,
                    android: nil,
                    apns: nil
                )
            )
            status = "Sent: \(response.name ?? "ok")"
            await env.audit.record(AuditEntry(
                accountID: env.accountManager.activeAccountID,
                projectID: project.projectId,
                action: "fcm.test_send",
                resource: "token",
                summary: "Sent FCM test message",
                reversible: false
            ))
        } catch let error as APIError {
            status = error.userMessage
        } catch {
            status = "Send failed."
        }
    }
}
