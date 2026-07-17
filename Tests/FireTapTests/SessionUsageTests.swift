import XCTest
@testable import FireTap

@MainActor
final class SessionUsageTests: XCTestCase {
    func testReadCountingAccumulates() {
        let usage = SessionUsage()
        usage.addReads(25)
        usage.addReads(10)
        XCTAssertEqual(usage.firestoreReads, 35)
    }

    func testNegativeCountsIgnored() {
        let usage = SessionUsage()
        usage.addReads(-5)
        XCTAssertEqual(usage.firestoreReads, 0)
    }

    func testLargeReadThreshold() {
        let usage = SessionUsage()
        XCTAssertFalse(usage.isLargeRead(pageSize: 25))
        XCTAssertTrue(usage.isLargeRead(pageSize: usage.largeReadThreshold))
        XCTAssertTrue(usage.isLargeRead(pageSize: 500))
    }

    func testReset() {
        let usage = SessionUsage()
        usage.addReads(100)
        usage.addWrites(3)
        usage.reset()
        XCTAssertEqual(usage.firestoreReads, 0)
        XCTAssertEqual(usage.firestoreWrites, 0)
    }
}
