import Foundation
import Observation

/// Enforces Production Safe Mode:
///  - Production projects open read-only.
///  - Writes are unlocked only after biometric authentication.
///  - The unlock automatically relocks after inactivity or when the app is
///    backgrounded.
///
/// This controller does not itself perform writes; feature code must consult
/// `canAttemptWrite` (and Pro entitlement) before offering destructive actions.
@MainActor
@Observable
final class SafeModeController {
    enum WriteAccess: Equatable {
        case locked
        case unlocked(until: Date)
    }

    private(set) var isProduction: Bool = false
    private(set) var writeAccess: WriteAccess = .locked
    private(set) var lastUnlockError: String?

    /// Inactivity window after which writes relock automatically.
    let inactivityTimeout: TimeInterval

    private let biometrics: BiometricAuthenticating
    private let clock: @Sendable () -> Date
    private var relockTask: Task<Void, Never>?

    init(
        biometrics: BiometricAuthenticating = BiometricAuthenticator(),
        inactivityTimeout: TimeInterval = 120,
        clock: @escaping @Sendable () -> Date = { .now }
    ) {
        self.biometrics = biometrics
        self.inactivityTimeout = inactivityTimeout
        self.clock = clock
    }

    /// True while writes are unlocked and the window has not elapsed.
    var isWriteUnlocked: Bool {
        switch writeAccess {
        case .locked:
            return false
        case .unlocked(let until):
            return clock() < until
        }
    }

    /// Whether a write may even be attempted right now. Production always
    /// requires an active unlock; other environments still require unlock but
    /// serve as the gate for offering destructive UI.
    var canAttemptWrite: Bool { isWriteUnlocked }

    var biometryName: String { biometrics.biometryName() }

    func configure(isProduction: Bool) {
        self.isProduction = isProduction
        relock()
    }

    /// Attempts to unlock writes via biometrics. Returns whether unlock
    /// succeeded. On production this is required before every destructive
    /// action once the window lapses.
    @discardableResult
    func requestWriteUnlock(reason: String? = nil) async -> Bool {
        lastUnlockError = nil
        let prompt = reason ?? "Unlock write access for this project"
        do {
            let ok = try await biometrics.authenticate(reason: prompt)
            guard ok else {
                lastUnlockError = "Authentication failed."
                return false
            }
            let until = clock().addingTimeInterval(inactivityTimeout)
            writeAccess = .unlocked(until: until)
            scheduleRelock(after: inactivityTimeout)
            return true
        } catch let error as BiometricError {
            lastUnlockError = Self.message(for: error)
            return false
        } catch {
            lastUnlockError = "Authentication is unavailable."
            return false
        }
    }

    /// Refreshes the inactivity window after user activity while unlocked.
    func noteActivity() {
        guard case .unlocked = writeAccess, isWriteUnlocked else { return }
        let until = clock().addingTimeInterval(inactivityTimeout)
        writeAccess = .unlocked(until: until)
        scheduleRelock(after: inactivityTimeout)
    }

    /// Relocks immediately (called on background/resign-active and on demand).
    func relock() {
        relockTask?.cancel()
        relockTask = nil
        writeAccess = .locked
    }

    private func scheduleRelock(after seconds: TimeInterval) {
        relockTask?.cancel()
        relockTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            guard !Task.isCancelled else { return }
            await MainActor.run { self?.relock() }
        }
    }

    private static func message(for error: BiometricError) -> String {
        switch error {
        case .unavailable: return "Face ID / passcode isn't available on this device."
        case .canceled: return "Unlock was canceled."
        case .failed: return "Authentication failed. Try again."
        case .lockout: return "Biometrics are locked. Use your passcode."
        }
    }
}
