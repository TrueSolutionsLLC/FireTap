import Foundation

/// Serializes concurrent token-refresh callers onto a single in-flight `Task`.
/// Used by Google Sign-In session wrappers so parallel API requests share one refresh.
final class TokenRefreshGate: @unchecked Sendable {
    private final class Box: @unchecked Sendable {
        let task: Task<String, Error>
        init(_ task: Task<String, Error>) { self.task = task }
    }

    private let lock = NSLock()
    private var inFlight: Box?

    /// Runs `operation` once for concurrent callers; others await the same task.
    func run(_ operation: @escaping @Sendable () async throws -> String) async throws -> String {
        let box: Box = lock.withLock {
            if let inFlight {
                return inFlight
            }
            let created = Box(Task { try await operation() })
            inFlight = created
            return created
        }
        do {
            let value = try await box.task.value
            lock.withLock {
                if inFlight === box { inFlight = nil }
            }
            return value
        } catch {
            lock.withLock {
                if inFlight === box { inFlight = nil }
            }
            throw error
        }
    }

    func cancel() {
        lock.withLock {
            inFlight?.task.cancel()
            inFlight = nil
        }
    }
}
