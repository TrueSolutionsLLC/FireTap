import XCTest

final class FireTapUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testAppLaunchesToWelcomeOrConfigState() {
        let app = XCUIApplication()
        app.launch()
        // The app should reach a stable first screen without crashing.
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
    }

    @MainActor
    func testLaunchShowsFireTapBrandingOrConfigurationCopy() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
        // Either OAuth-configured welcome or honest not-configured state.
        let hasFireTap = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "FireTap")).firstMatch.waitForExistence(timeout: 5)
        let hasGoogle = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "Google")).firstMatch.exists
        let hasConfigured = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "configured")).firstMatch.exists
        XCTAssertTrue(hasFireTap || hasGoogle || hasConfigured, "Expected welcome or configuration messaging")
    }
}
