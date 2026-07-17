import Foundation
import Observation

/// Tracks billable operations caused by the app during the current session so
/// the UI can be honest about the cost of viewing data. Firestore reads are the
/// primary signal (viewing documents creates billable reads).
@MainActor
@Observable
final class SessionUsage {
    private(set) var firestoreReads: Int = 0
    private(set) var firestoreWrites: Int = 0
    private(set) var firestoreDeletes: Int = 0

    /// A read is considered "large" (worth warning about) above this count.
    let largeReadThreshold = 300

    func addReads(_ count: Int) { firestoreReads += max(0, count) }
    func addWrites(_ count: Int) { firestoreWrites += max(0, count) }
    func addDeletes(_ count: Int) { firestoreDeletes += max(0, count) }

    func isLargeRead(pageSize: Int) -> Bool { pageSize >= largeReadThreshold }

    func reset() {
        firestoreReads = 0
        firestoreWrites = 0
        firestoreDeletes = 0
    }
}
