import XCTest
@testable import FireTap

@MainActor
final class SafeModeTests: XCTestCase {
    func testUnlockSucceedsWithBiometrics() async {
        let controller = SafeModeController(biometrics: FakeBiometrics(result: .success(true)), inactivityTimeout: 60)
        controller.configure(isProduction: true)
        XCTAssertFalse(controller.isWriteUnlocked)
        let ok = await controller.requestWriteUnlock()
        XCTAssertTrue(ok)
        XCTAssertTrue(controller.isWriteUnlocked)
    }

    func testUnlockFailsWhenBiometricsFail() async {
        let controller = SafeModeController(biometrics: FakeBiometrics(result: .failure(.failed)))
        let ok = await controller.requestWriteUnlock()
        XCTAssertFalse(ok)
        XCTAssertFalse(controller.isWriteUnlocked)
        XCTAssertNotNil(controller.lastUnlockError)
    }

    func testCanceledUnlockReportsCancel() async {
        let controller = SafeModeController(biometrics: FakeBiometrics(result: .failure(.canceled)))
        let ok = await controller.requestWriteUnlock()
        XCTAssertFalse(ok)
        XCTAssertEqual(controller.lastUnlockError, "Unlock was canceled.")
    }

    func testRelockClearsWriteAccess() async {
        let controller = SafeModeController(biometrics: FakeBiometrics(result: .success(true)))
        _ = await controller.requestWriteUnlock()
        XCTAssertTrue(controller.isWriteUnlocked)
        controller.relock()
        XCTAssertFalse(controller.isWriteUnlocked)
    }

    func testWriteAccessExpiresWithClock() async {
        let clock = MutableClock(Date(timeIntervalSince1970: 1000))
        let controller = SafeModeController(
            biometrics: FakeBiometrics(result: .success(true)),
            inactivityTimeout: 60,
            clock: { clock.now }
        )
        _ = await controller.requestWriteUnlock()
        XCTAssertTrue(controller.isWriteUnlocked)
        clock.now = clock.now.addingTimeInterval(61) // advance past timeout
        XCTAssertFalse(controller.isWriteUnlocked)
    }

    func testConfigureRelocks() async {
        let controller = SafeModeController(biometrics: FakeBiometrics(result: .success(true)))
        _ = await controller.requestWriteUnlock()
        XCTAssertTrue(controller.isWriteUnlocked)
        controller.configure(isProduction: true)
        XCTAssertFalse(controller.isWriteUnlocked)
    }
}
