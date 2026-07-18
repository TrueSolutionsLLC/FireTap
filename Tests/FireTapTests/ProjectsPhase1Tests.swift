import XCTest
@testable import FireTap

final class ProjectListOrderingTests: XCTestCase {
    func testActiveProjectsSortBeforeInactiveThenAlphabetically() {
        let projects = [
            FirebaseProject.fixture(id: "zeta", name: "Zeta", state: "ACTIVE"),
            FirebaseProject.fixture(id: "alpha-del", name: "Alpha", state: "DELETED"),
            FirebaseProject.fixture(id: "beta", name: "Beta", state: "ACTIVE"),
            FirebaseProject.fixture(id: "gamma", name: "Gamma", state: "DELETE_REQUESTED")
        ]
        let sorted = ProjectListOrdering.sort(projects)
        XCTAssertEqual(sorted.map(\.projectId), ["beta", "zeta", "alpha-del", "gamma"])
    }

    func testPinnedFloatAboveActiveBand() {
        let projects = [
            FirebaseProject.fixture(id: "a", name: "A"),
            FirebaseProject.fixture(id: "b", name: "B")
        ]
        let sorted = ProjectListOrdering.sort(projects, pinnedIDs: ["b"])
        XCTAssertEqual(sorted.map(\.projectId), ["b", "a"])
    }

    func testSearchMatchesNameIdAndNumber() {
        let projects = [
            FirebaseProject.fixture(id: "demo-app", name: "Demo", number: "999"),
            FirebaseProject.fixture(id: "other", name: "Other", number: "111")
        ]
        XCTAssertEqual(ProjectListOrdering.filter(projects, searchText: "demo").map(\.projectId), ["demo-app"])
        XCTAssertEqual(ProjectListOrdering.filter(projects, searchText: "999").map(\.projectId), ["demo-app"])
        XCTAssertEqual(ProjectListOrdering.filter(projects, searchText: "  ").count, 2)
    }

    func testEmptyFilterReturnsAll() {
        let projects = [FirebaseProject.fixture(id: "a")]
        XCTAssertEqual(ProjectListOrdering.filter(projects, searchText: "").count, 1)
    }
}

@MainActor
final class ProjectsViewModelTests: XCTestCase {
    func testEmptyProjectResults() async {
        let service = FakeProjectsService()
        service.pages = [[]]
        let prefs = PreferencesStore(defaults: UserDefaults(suiteName: UUID().uuidString)!)
        let model = ProjectsViewModel(projectsService: service, preferences: prefs, accountID: "acc")
        await model.load()
        XCTAssertEqual(model.phase.value?.count, 0)
        XCTAssertTrue(model.displayedProjects.isEmpty)
    }

    func testOfflineListFailure() async {
        let service = FakeProjectsService()
        service.listError = .transport(underlying: "-1009")
        let prefs = PreferencesStore(defaults: UserDefaults(suiteName: UUID().uuidString)!)
        let model = ProjectsViewModel(projectsService: service, preferences: prefs, accountID: "acc")
        await model.load()
        XCTAssertEqual(model.phase.error, .transport(underlying: "-1009"))
    }

    func testDisplayedProjectsRespectSearch() async {
        let service = FakeProjectsService()
        service.pages = [[
            .fixture(id: "keep", name: "Keep Me"),
            .fixture(id: "drop", name: "Drop Me")
        ]]
        let prefs = PreferencesStore(defaults: UserDefaults(suiteName: UUID().uuidString)!)
        let model = ProjectsViewModel(projectsService: service, preferences: prefs, accountID: "acc")
        await model.load()
        model.searchText = "keep"
        XCTAssertEqual(model.displayedProjects.map(\.projectId), ["keep"])
    }
}

final class ProjectDecodingTests: XCTestCase {
    func testDecodesListProjectsResponse() throws {
        let json = """
        {
          "results": [
            {
              "projectId": "my-app",
              "projectNumber": "123456789",
              "displayName": "My App",
              "state": "ACTIVE",
              "resources": { "locationId": "us-central" }
            }
          ],
          "nextPageToken": "PAGE2"
        }
        """.data(using: .utf8)!
        let response = try JSONDecoder().decode(ListProjectsResponse.self, from: json)
        XCTAssertEqual(response.nextPageToken, "PAGE2")
        let project = try XCTUnwrap(response.results?.first)
        XCTAssertEqual(project.projectId, "my-app")
        XCTAssertEqual(project.projectNumber, "123456789")
        XCTAssertTrue(project.isActive)
        XCTAssertEqual(project.regionDisplay, "us-central")
    }

    func testMalformedResponseThrows() {
        let json = Data(#"{"results":[{"projectId":1}]}"#.utf8)
        XCTAssertThrowsError(try JSONDecoder().decode(ListProjectsResponse.self, from: json))
    }
}

@MainActor
final class LastProjectRestorationTests: XCTestCase {
    private func makeEnv(
        accountManager: AccountManager,
        preferences: PreferencesStore,
        projects: ProjectsService,
        tokenProvider: any TokenProviding
    ) -> AppEnvironment {
        let api = GoogleAPIClient(transport: HTTPClient(), tokenProvider: tokenProvider)
        return AppEnvironment(
            accountManager: accountManager,
            preferences: preferences,
            tokenProvider: tokenProvider,
            apiClient: api,
            safeMode: SafeModeController(),
            appLock: AppLockController(),
            store: StoreManager(),
            audit: EncryptedAuditTrail(service: "test.audit.\(UUID().uuidString)"),
            sessionUsage: SessionUsage(),
            projectsService: projects,
            firestoreService: LiveFirestoreService(api: api),
            authService: LiveAuthService(api: api),
            storageService: LiveStorageService(api: api),
            functionsService: LiveFunctionsService(api: api),
            loggingService: LiveLoggingService(api: api),
            monitoringService: LiveMonitoringService(api: api),
            realtimeDatabaseService: LiveRealtimeDatabaseService(api: api),
            remoteConfigService: LiveRemoteConfigService(api: api),
            hostingService: LiveHostingService(api: api),
            appCheckService: LiveAppCheckService(api: api),
            iamService: LiveIAMService(api: api),
            fcmService: LiveFCMService(api: api),
            rulesService: LiveRulesService(api: api),
            appDistributionService: LiveAppDistributionService(api: api),
            extensionsService: LiveExtensionsService(api: api)
        )
    }

    func testRevokedLastProjectClearsSelection() async {
        let projects = FakeProjectsService()
        projects.projectError = .permissionDenied(message: "denied")
        let prefs = PreferencesStore(defaults: UserDefaults(suiteName: UUID().uuidString)!)
        prefs.setLastOpenedProjectID("gone-project", account: "acc")

        let session = FakeGoogleSignInSession()
        session.restoreResult = .fixture(id: "acc")
        let accountManager = AccountManager(session: session, isConfigured: true)
        await accountManager.bootstrap()

        let tokenProvider = GoogleSignInTokenProvider(session: session)
        let env = makeEnv(
            accountManager: accountManager,
            preferences: prefs,
            projects: projects,
            tokenProvider: tokenProvider
        )

        await env.restoreLastProjectIfAccessible()
        XCTAssertNil(env.selectedProject)
        XCTAssertNil(prefs.lastOpenedProjectID(account: "acc"))
    }

    func testAccessibleLastProjectReopens() async {
        let project = FirebaseProject.fixture(id: "keep-me", name: "Keep")
        let projects = FakeProjectsService()
        projects.projectByID = ["keep-me": project]
        let prefs = PreferencesStore(defaults: UserDefaults(suiteName: UUID().uuidString)!)
        prefs.setLastOpenedProjectID("keep-me", account: "acc")

        let session = FakeGoogleSignInSession()
        session.restoreResult = .fixture(id: "acc")
        let accountManager = AccountManager(session: session, isConfigured: true)
        await accountManager.bootstrap()

        let tokenProvider = GoogleSignInTokenProvider(session: session)
        let env = makeEnv(
            accountManager: accountManager,
            preferences: prefs,
            projects: projects,
            tokenProvider: tokenProvider
        )

        await env.restoreLastProjectIfAccessible()
        XCTAssertEqual(env.selectedProject?.projectId, "keep-me")
    }
}
