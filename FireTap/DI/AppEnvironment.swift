import Foundation
import Observation

@MainActor
@Observable
final class AppEnvironment {
    let accountManager: AccountManager
    let preferences: PreferencesStore
    let tokenProvider: any TokenProviding
    let apiClient: GoogleAPIClient
    let safeMode: SafeModeController
    let appLock: AppLockController
    let store: StoreManager
    let audit: AuditLogging
    let sessionUsage: SessionUsage
    let savedQueries: SavedQueriesStore

    let projectsService: ProjectsService
    let firestoreService: FirestoreService
    let authService: AuthService
    let storageService: StorageService
    let functionsService: FunctionsService
    let loggingService: LoggingService
    let monitoringService: MonitoringService
    let realtimeDatabaseService: RealtimeDatabaseService
    let remoteConfigService: RemoteConfigService
    let hostingService: HostingService
    let appCheckService: AppCheckService
    let iamService: IAMService
    let fcmService: FCMService
    let rulesService: RulesService
    let appDistributionService: AppDistributionService
    let extensionsService: ExtensionsService

    var selectedProject: FirebaseProject?
    var selectedProjectEnvironment: ProjectEnvironment = .unlabeled
    private(set) var isRestoringProject = false
    var pendingDeepLink: FireTapDeepLink?
    var pendingNavigationModule: ServiceModule?

    /// Free-tier sticky project id (first opened while not Pro).
    var freeTierProjectID: String? {
        get { UserDefaults.standard.string(forKey: "pc.freeProjectID") }
        set { UserDefaults.standard.set(newValue, forKey: "pc.freeProjectID") }
    }

    init(
        accountManager: AccountManager,
        preferences: PreferencesStore,
        tokenProvider: any TokenProviding,
        apiClient: GoogleAPIClient,
        safeMode: SafeModeController,
        appLock: AppLockController,
        store: StoreManager,
        audit: AuditLogging,
        sessionUsage: SessionUsage,
        savedQueries: SavedQueriesStore = SavedQueriesStore(),
        projectsService: ProjectsService,
        firestoreService: FirestoreService,
        authService: AuthService,
        storageService: StorageService,
        functionsService: FunctionsService,
        loggingService: LoggingService,
        monitoringService: MonitoringService,
        realtimeDatabaseService: RealtimeDatabaseService,
        remoteConfigService: RemoteConfigService,
        hostingService: HostingService,
        appCheckService: AppCheckService,
        iamService: IAMService,
        fcmService: FCMService,
        rulesService: RulesService,
        appDistributionService: AppDistributionService,
        extensionsService: ExtensionsService
    ) {
        self.accountManager = accountManager
        self.preferences = preferences
        self.tokenProvider = tokenProvider
        self.apiClient = apiClient
        self.safeMode = safeMode
        self.appLock = appLock
        self.store = store
        self.audit = audit
        self.sessionUsage = sessionUsage
        self.savedQueries = savedQueries
        self.projectsService = projectsService
        self.firestoreService = firestoreService
        self.authService = authService
        self.storageService = storageService
        self.functionsService = functionsService
        self.loggingService = loggingService
        self.monitoringService = monitoringService
        self.realtimeDatabaseService = realtimeDatabaseService
        self.remoteConfigService = remoteConfigService
        self.hostingService = hostingService
        self.appCheckService = appCheckService
        self.iamService = iamService
        self.fcmService = fcmService
        self.rulesService = rulesService
        self.appDistributionService = appDistributionService
        self.extensionsService = extensionsService
    }

    var featureGate: FeatureGate { FeatureGate(isPro: store.isPro) }

    func open(project: FirebaseProject, environment: ProjectEnvironment, accountID: String) {
        if !featureGate.canOpenProject(id: project.projectId, freeProjectID: freeTierProjectID) {
            // Caller should present upgrade UI; still record preference attempt.
            return
        }
        if freeTierProjectID == nil { freeTierProjectID = project.projectId }
        preferences.setLastOpenedProjectID(project.projectId, account: accountID)
        selectedProjectEnvironment = environment
        selectedProject = project
        safeMode.configure(isProduction: environment.isProduction)
    }

    func closeProject() {
        selectedProject = nil
        safeMode.relock()
    }

    func restoreLastProjectIfAccessible() async {
        guard let accountID = accountManager.activeAccountID else {
            selectedProject = nil
            return
        }
        guard let lastID = preferences.lastOpenedProjectID(account: accountID), !lastID.isEmpty else {
            selectedProject = nil
            return
        }
        isRestoringProject = true
        defer { isRestoringProject = false }
        do {
            let project = try await projectsService.project(id: lastID)
            if !featureGate.canOpenProject(id: project.projectId, freeProjectID: freeTierProjectID) {
                selectedProject = nil
                return
            }
            let environment = preferences.environment(for: project.projectId, account: accountID)
            open(project: project, environment: environment, accountID: accountID)
        } catch APIError.notFound, APIError.permissionDenied {
            preferences.setLastOpenedProjectID(nil, account: accountID)
            selectedProject = nil
            safeMode.relock()
        } catch {
            selectedProject = nil
        }
    }

    func handleAccountSessionChange() {
        selectedProject = nil
        pendingDeepLink = nil
        pendingNavigationModule = nil
        safeMode.relock()
        sessionUsage.reset()
    }

    /// Stores and resolves a `firetap://` deep link when the user is signed in.
    func handleDeepLink(_ url: URL) async {
        guard let link = FireTapDeepLinkParser.parse(url) else { return }
        pendingDeepLink = link
        await resolvePendingDeepLink()
    }

    func resolvePendingDeepLink() async {
        guard let link = pendingDeepLink else { return }
        guard accountManager.isSignedIn, let accountID = accountManager.activeAccountID else { return }

        if selectedProject?.projectId != link.projectID {
            do {
                let project = try await projectsService.project(id: link.projectID)
                if !featureGate.canOpenProject(id: project.projectId, freeProjectID: freeTierProjectID) {
                    pendingDeepLink = nil
                    return
                }
                let environment = preferences.environment(for: project.projectId, account: accountID)
                open(project: project, environment: environment, accountID: accountID)
            } catch {
                pendingDeepLink = nil
                return
            }
        }

        if let module = link.module {
            pendingNavigationModule = module
        }
        pendingDeepLink = nil
    }

    func clearPendingNavigationModule() {
        pendingNavigationModule = nil
    }

    static func live() -> AppEnvironment {
        let signInSession = LiveGoogleSignInSession()
        let tokenProvider = GoogleSignInTokenProvider(session: signInSession)
        let transport = HTTPClient()
        let apiClient = GoogleAPIClient(transport: transport, tokenProvider: tokenProvider)
        let accountManager = AccountManager(session: signInSession)
        return AppEnvironment(
            accountManager: accountManager,
            preferences: PreferencesStore(),
            tokenProvider: tokenProvider,
            apiClient: apiClient,
            safeMode: SafeModeController(),
            appLock: AppLockController(),
            store: StoreManager(),
            audit: EncryptedAuditTrail(),
            sessionUsage: SessionUsage(),
            savedQueries: SavedQueriesStore(),
            projectsService: LiveProjectsService(api: apiClient),
            firestoreService: LiveFirestoreService(api: apiClient),
            authService: LiveAuthService(api: apiClient),
            storageService: LiveStorageService(api: apiClient),
            functionsService: LiveFunctionsService(api: apiClient),
            loggingService: LiveLoggingService(api: apiClient),
            monitoringService: LiveMonitoringService(api: apiClient),
            realtimeDatabaseService: LiveRealtimeDatabaseService(api: apiClient),
            remoteConfigService: LiveRemoteConfigService(api: apiClient),
            hostingService: LiveHostingService(api: apiClient),
            appCheckService: LiveAppCheckService(api: apiClient),
            iamService: LiveIAMService(api: apiClient),
            fcmService: LiveFCMService(api: apiClient),
            rulesService: LiveRulesService(api: apiClient),
            appDistributionService: LiveAppDistributionService(api: apiClient),
            extensionsService: LiveExtensionsService(api: apiClient)
        )
    }
}
