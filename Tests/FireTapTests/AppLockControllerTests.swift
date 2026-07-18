import XCTest
@testable import FireTap

@MainActor
final class AppLockControllerTests: XCTestCase {
    private func makeDefaults() -> UserDefaults {
        UserDefaults(suiteName: UUID().uuidString)!
    }

    func testLocksOnLaunchWhenEnabled() {
        let defaults = makeDefaults()
        defaults.set(true, forKey: "pc.appLock.enabled")
        let controller = AppLockController(defaults: defaults, biometrics: FakeBiometrics())
        controller.configureOnLaunch()
        XCTAssertTrue(controller.isLocked)
    }

    func testUnlockSucceedsWithBiometrics() async {
        let controller = AppLockController(defaults: makeDefaults(), biometrics: FakeBiometrics(result: .success(true)))
        controller.isEnabled = true
        XCTAssertTrue(controller.isLocked)
        let ok = await controller.unlock()
        XCTAssertTrue(ok)
        XCTAssertFalse(controller.isLocked)
    }

    func testUnlockFailsWhenBiometricsFail() async {
        let controller = AppLockController(defaults: makeDefaults(), biometrics: FakeBiometrics(result: .failure(.failed)))
        controller.isEnabled = true
        let ok = await controller.unlock()
        XCTAssertFalse(ok)
        XCTAssertTrue(controller.isLocked)
        XCTAssertNotNil(controller.lastUnlockError)
    }

    func testResignActiveLocksWhenEnabled() async {
        let controller = AppLockController(defaults: makeDefaults(), biometrics: FakeBiometrics(result: .success(true)))
        controller.isEnabled = true
        _ = await controller.unlock()
        XCTAssertFalse(controller.isLocked)
        controller.handleResignActive()
        XCTAssertTrue(controller.isLocked)
    }

    func testDisablingClearsLock() async {
        let controller = AppLockController(defaults: makeDefaults(), biometrics: FakeBiometrics(result: .success(true)))
        controller.isEnabled = true
        controller.isEnabled = false
        XCTAssertFalse(controller.isLocked)
    }

    func testInactivityTimeoutPersists() {
        let defaults = makeDefaults()
        let controller = AppLockController(defaults: defaults, biometrics: FakeBiometrics())
        controller.inactivityTimeout = .fiveMinutes
        XCTAssertEqual(controller.inactivityTimeout, .fiveMinutes)
        let restored = AppLockController(defaults: defaults, biometrics: FakeBiometrics())
        XCTAssertEqual(restored.inactivityTimeout, .fiveMinutes)
    }
}
