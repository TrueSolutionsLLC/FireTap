import Foundation
import Observation

/// App-wide lock overlay. When enabled, the app locks on launch, after
/// inactivity, and when backgrounded. Unlock uses device biometrics /
/// passcode via `BiometricAuthenticator`.
@MainActor
@Observable
final class AppLockController {
    enum InactivityTimeout: TimeInterval, CaseIterable, Identifiable {
        case oneMinute = 60
        case twoMinutes = 120
        case fiveMinutes = 300

        var id: TimeInterval { rawValue }

        var title: String {
            switch self {
            case .oneMinute: return "1 minute"
            case .twoMinutes: return "2 minutes"
            case .fiveMinutes: return "5 minutes"
            }
        }

        static func nearest(to value: TimeInterval) -> InactivityTimeout {
            allCases.min(by: { abs($0.rawValue - value) < abs($1.rawValue - value) }) ?? .twoMinutes
        }
    }

    private(set) var isLocked = false
    private(set) var lastUnlockError: String?
    var isEnabled: Bool {
        didSet {
            defaults.set(isEnabled, forKey: Keys.enabled)
            if isEnabled {
                lock()
            } else {
                unlockWithoutAuthentication()
            }
        }
    }
    var inactivityTimeout: InactivityTimeout {
        didSet {
            defaults.set(inactivityTimeout.rawValue, forKey: Keys.inactivity)
            if !isLocked, isEnabled {
                scheduleInactivityLock()
            }
        }
    }
    var screenshotPrivacyEnabled: Bool {
        didSet { defaults.set(screenshotPrivacyEnabled, forKey: Keys.screenshotPrivacy) }
    }

    private let defaults: UserDefaults
    private let biometrics: BiometricAuthenticating
    private let clock: @Sendable () -> Date
    private var inactivityTask: Task<Void, Never>?

    private enum Keys {
        static let enabled = "pc.appLock.enabled"
        static let inactivity = "pc.appLock.inactivityTimeout"
        static let screenshotPrivacy = "pc.appLock.screenshotPrivacy"
    }

    init(
        defaults: UserDefaults = .standard,
        biometrics: BiometricAuthenticating = BiometricAuthenticator(),
        clock: @escaping @Sendable () -> Date = { .now }
    ) {
        self.defaults = defaults
        self.biometrics = biometrics
        self.clock = clock
        self.isEnabled = defaults.bool(forKey: Keys.enabled)
        let storedTimeout = defaults.double(forKey: Keys.inactivity)
        self.inactivityTimeout = InactivityTimeout.nearest(to: storedTimeout > 0 ? storedTimeout : InactivityTimeout.twoMinutes.rawValue)
        self.screenshotPrivacyEnabled = defaults.bool(forKey: Keys.screenshotPrivacy)
    }

    var biometryName: String { biometrics.biometryName() }

    /// Call once on launch after preferences are loaded.
    func configureOnLaunch() {
        if isEnabled {
            isLocked = true
        }
    }

    func noteActivity() {
        guard isEnabled, !isLocked else { return }
        scheduleInactivityLock()
    }

    /// Locks immediately when the app leaves the foreground and App Lock is enabled.
    func handleResignActive() {
        guard isEnabled else { return }
        lock()
    }

    @discardableResult
    func unlock(reason: String? = nil) async -> Bool {
        lastUnlockError = nil
        let prompt = reason ?? "Unlock \(AppConfig.displayName)"
        do {
            let ok = try await biometrics.authenticate(reason: prompt)
            guard ok else {
                lastUnlockError = "Authentication failed."
                return false
            }
            isLocked = false
            scheduleInactivityLock()
            return true
        } catch let error as BiometricError {
            lastUnlockError = Self.message(for: error)
            return false
        } catch {
            lastUnlockError = "Authentication is unavailable."
            return false
        }
    }

    func lock() {
        inactivityTask?.cancel()
        inactivityTask = nil
        isLocked = true
    }

    private func unlockWithoutAuthentication() {
        inactivityTask?.cancel()
        inactivityTask = nil
        isLocked = false
        lastUnlockError = nil
    }

    private func scheduleInactivityLock() {
        inactivityTask?.cancel()
        let seconds = inactivityTimeout.rawValue
        inactivityTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            guard !Task.isCancelled else { return }
            await MainActor.run { self?.lock() }
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
