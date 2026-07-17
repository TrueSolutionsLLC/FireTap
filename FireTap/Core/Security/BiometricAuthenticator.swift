import Foundation
import LocalAuthentication

/// Abstraction over biometric / passcode authentication so Safe Mode and App
/// Lock can be tested with a deterministic fake.
protocol BiometricAuthenticating: Sendable {
    /// Whether device authentication is currently available.
    func canEvaluate() -> Bool
    /// Human-readable biometry name ("Face ID", "Touch ID", or "passcode").
    func biometryName() -> String
    /// Prompts for authentication. Returns `true` on success, throws on error,
    /// and maps user cancellation to `false`-adjacent typed errors.
    func authenticate(reason: String) async throws -> Bool
}

enum BiometricError: Error, Equatable {
    case unavailable
    case canceled
    case failed
    case lockout
}

struct BiometricAuthenticator: BiometricAuthenticating {
    func canEvaluate() -> Bool {
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error)
    }

    func biometryName() -> String {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
        switch context.biometryType {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        case .opticID: return "Optic ID"
        default: return "device passcode"
        }
    }

    func authenticate(reason: String) async throws -> Bool {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            throw BiometricError.unavailable
        }
        do {
            return try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
        } catch let laError as LAError {
            switch laError.code {
            case .userCancel, .appCancel, .systemCancel:
                throw BiometricError.canceled
            case .biometryLockout:
                throw BiometricError.lockout
            default:
                throw BiometricError.failed
            }
        }
    }
}
