import Foundation
import Observation

/// Composition root. Builds and owns the app's long-lived services and wires
/// them together via protocols so the production app uses live implementations
/// while tests can inject deterministic fakes.
///
/// A single `GoogleAPIClient` is shared across account switches: the underlying
/// `TokenService` tracks which account is active, so changing accounts changes
/// the token the client sends without rebuilding anything.
@MainActor
@Observable
final class AppEnvironment {
    let accountManager: AccountManager
    let preferences: PreferencesStore
    let tokenService: TokenService
    let apiClient: GoogleAPIClient
    let safeMode: SafeModeController
    let store: StoreManager
    let audit: AuditLogging
    let sessionUsage: SessionUsage

    // Feature services (protocol-typed for testability).
    let projectsService: ProjectsService
    let firestoreService: FirestoreService
    let authService: AuthService
    let storageService: StorageService

    // MARK: Router state

    /// The project the user is currently working inside. `nil` shows the
    /// project picker. Changing accounts resets this.
    var selectedProject: FirebaseProject?

    /// Environment label of the selected project (drives Safe Mode + indicator).
    var selectedProjectEnvironment: ProjectEnvironment = .unlabeled

    init(
        accountManager: AccountManager,
        preferences: PreferencesStore,
        tokenService: TokenService,
        apiClient: GoogleAPIClient,
        safeMode: SafeModeController,
        store: StoreManager,
        audit: AuditLogging,
        sessionUsage: SessionUsage,
        projectsService: ProjectsService,
        firestoreService: FirestoreService,
        authService: AuthService,
        storageService: StorageService
    ) {
        self.accountManager = accountManager
        self.preferences = preferences
        self.tokenService = tokenService
        self.apiClient = apiClient
        self.safeMode = safeMode
        self.store = store
        self.audit = audit
        self.sessionUsage = sessionUsage
        self.projectsService = projectsService
        self.firestoreService = firestoreService
        self.authService = authService
        self.storageService = storageService
    }

    /// The current feature gate combining Pro entitlement with the free-tier
    /// project allowance.
    var featureGate: FeatureGate { FeatureGate(isPro: store.isPro) }

    /// Opens a project, enforcing Safe Mode configuration for its environment.
    func open(project: FirebaseProject, environment: ProjectEnvironment, accountID: String) {
        preferences.setLastOpenedProjectID(project.projectId, account: accountID)
        selectedProjectEnvironment = environment
        selectedProject = project
        safeMode.configure(isProduction: environment.isProduction)
    }

    func closeProject() {
        selectedProject = nil
        safeMode.relock()
    }

    /// Builds the production environment with live implementations.
    static func live() -> AppEnvironment {
        let credentialStore = KeychainCredentialStore()
        let oauthClient = GoogleOAuthClient()
        let transport = HTTPClient()
        let tokenService = TokenService(oauthClient: oauthClient, credentialStore: credentialStore)
        let apiClient = GoogleAPIClient(transport: transport, tokenProvider: tokenService)
        let accountManager = AccountManager(
            oauthClient: oauthClient,
            credentialStore: credentialStore,
            tokenService: tokenService
        )
        return AppEnvironment(
            accountManager: accountManager,
            preferences: PreferencesStore(),
            tokenService: tokenService,
            apiClient: apiClient,
            safeMode: SafeModeController(),
            store: StoreManager(),
            audit: EncryptedAuditTrail(),
            sessionUsage: SessionUsage(),
            projectsService: LiveProjectsService(api: apiClient),
            firestoreService: LiveFirestoreService(api: apiClient),
            authService: LiveAuthService(api: apiClient),
            storageService: LiveStorageService(api: apiClient)
        )
    }
}
