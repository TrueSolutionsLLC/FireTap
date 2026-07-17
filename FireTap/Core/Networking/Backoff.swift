import Foundation

/// Exponential backoff with full jitter, used between retryable failures.
///
/// Delay for attempt `n` (0-based) is a uniform random value in
/// `[0, min(cap, base * 2^n)]`. A server-provided `Retry-After` always wins
/// over the computed delay.
struct Backoff: Sendable {
    let base: TimeInterval
    let cap: TimeInterval
    let maxRetries: Int

    init(base: TimeInterval = 0.5, cap: TimeInterval = 20, maxRetries: Int = 4) {
        self.base = base
        self.cap = cap
        self.maxRetries = maxRetries
    }

    /// Computes the delay for a given zero-based attempt index.
    func delay(forAttempt attempt: Int, retryAfter: TimeInterval? = nil) -> TimeInterval {
        if let retryAfter { return retryAfter }
        let exponential = base * pow(2.0, Double(max(0, attempt)))
        let bounded = min(cap, exponential)
        return Double.random(in: 0...bounded)
    }
}
