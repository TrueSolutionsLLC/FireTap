import XCTest
@testable import FireTap

final class IncidentAggregatorTests: XCTestCase {
    func testMapsFunctionFailuresWithoutInventingSeverity() {
        let function = CloudFunctionSummary(
            name: "projects/p/locations/us/functions/api",
            environment: "GEN_2",
            status: "FAILED",
            region: "us-central1",
            runtime: "nodejs20",
            trigger: "HTTPS",
            url: nil,
            updateTime: nil
        )
        let incidents = IncidentAggregator.aggregate(
            functionErrors: [function],
            logEntries: [],
            auditEntries: []
        )
        XCTAssertEqual(incidents.count, 1)
        XCTAssertEqual(incidents[0].severity, "FAILED")
        XCTAssertEqual(incidents[0].sourceModule, "functions")
    }

    func testIgnoresHealthyFunctions() {
        let function = CloudFunctionSummary(
            name: "projects/p/locations/us/functions/ok",
            environment: "GEN_1",
            status: "ACTIVE",
            region: nil,
            runtime: nil,
            trigger: nil,
            url: nil,
            updateTime: nil
        )
        let incidents = IncidentAggregator.aggregate(
            functionErrors: [function],
            logEntries: [],
            auditEntries: []
        )
        XCTAssertTrue(incidents.isEmpty)
    }

    func testMapsCriticalLogs() {
        let entry = LogEntry(
            timestamp: "2026-01-01T00:00:00Z",
            severity: "ERROR",
            resource: nil,
            textPayload: "boom",
            jsonPayload: nil,
            insertId: "1",
            trace: nil
        )
        let incidents = IncidentAggregator.aggregate(
            functionErrors: [],
            logEntries: [entry],
            auditEntries: []
        )
        XCTAssertEqual(incidents.count, 1)
        XCTAssertEqual(incidents[0].severity, "ERROR")
    }
}

final class FirestoreQueryEncodingTests: XCTestCase {
    func testStructuredQueryEncodesWhereAndLimit() throws {
        let query = FirestoreStructuredQuery(
            from: [.init(collectionId: "users")],
            where: .init(fieldFilter: .init(
                field: .init(fieldPath: "role"),
                op: "EQUAL",
                value: .string("admin")
            )),
            orderBy: [.init(field: .init(fieldPath: "created"), direction: "DESCENDING")],
            limit: 25
        )
        let data = try JSONEncoder().encode(RunQueryRequest(structuredQuery: query))
        let json = String(data: data, encoding: .utf8) ?? ""
        XCTAssertTrue(json.contains("users"))
        XCTAssertTrue(json.contains("EQUAL"))
        XCTAssertTrue(json.contains("admin"))
        XCTAssertTrue(json.contains("25") || json.contains("\"limit\":25"))
    }

    func testSavedQueryRoundTrip() throws {
        let saved = SavedFirestoreQuery.make(
            title: "Admins",
            collectionID: "users",
            fieldPath: "role",
            op: "EQUAL",
            stringValue: "admin",
            limit: 10
        )
        let data = try JSONEncoder().encode(saved)
        let decoded = try JSONDecoder().decode(SavedFirestoreQuery.self, from: data)
        XCTAssertEqual(decoded.collectionID, "users")
        XCTAssertEqual(decoded.toStructuredQuery().limit, 10)
    }
}

final class LoggingFilterTests: XCTestCase {
    func testBuildsSeverityFilter() {
        let filter = LoggingFilter.build(severityAtLeast: "ERROR")
        XCTAssertTrue(filter.contains("ERROR"))
    }
}
