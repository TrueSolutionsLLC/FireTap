import XCTest
@testable import FireTap

final class AuditTrailTests: XCTestCase {
    private func makeTrail() -> EncryptedAuditTrail {
        EncryptedAuditTrail(
            service: "com.truesolutions.firetap.tests.audit.\(UUID().uuidString)",
            fileName: "audit-\(UUID().uuidString).log"
        )
    }

    func testRecordAndReadRoundTrip() async {
        let trail = makeTrail()
        let entry = AuditEntry(accountID: "acc", projectID: "proj",
                               action: "delete.document", resource: "orders/ord_1",
                               summary: "Deleted document", reversible: false)
        await trail.record(entry)
        let entries = await trail.entries(limit: 10)
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.action, "delete.document")
        XCTAssertEqual(entries.first?.resource, "orders/ord_1")
        await trail.clear()
    }

    func testEntriesAreOrderedNewestFirst() async {
        let trail = makeTrail()
        await trail.record(AuditEntry(timestamp: Date(timeIntervalSince1970: 100), accountID: nil,
                                      projectID: "p", action: "a1", resource: "r", summary: "s"))
        await trail.record(AuditEntry(timestamp: Date(timeIntervalSince1970: 200), accountID: nil,
                                      projectID: "p", action: "a2", resource: "r", summary: "s"))
        let entries = await trail.entries(limit: 10)
        XCTAssertEqual(entries.map(\.action), ["a2", "a1"])
        await trail.clear()
    }

    func testClearRemovesEntries() async {
        let trail = makeTrail()
        await trail.record(AuditEntry(accountID: nil, projectID: "p", action: "a", resource: "r", summary: "s"))
        await trail.clear()
        let entries = await trail.entries(limit: 10)
        XCTAssertTrue(entries.isEmpty)
    }
}
