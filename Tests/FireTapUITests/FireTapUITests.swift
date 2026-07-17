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
}
