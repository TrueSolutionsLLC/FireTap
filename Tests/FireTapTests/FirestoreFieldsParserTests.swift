import XCTest
@testable import FireTap

final class FirestoreFieldsParserTests: XCTestCase {
    func testParseSimpleInfersBoolIntDoubleAndString() throws {
        let text = """
        name: Alice
        active: true
        count: 42
        score: 3.14
        note: plain text
        """
        let fields = try FirestoreFieldsParser.parseSimple(text)
        XCTAssertEqual(fields["name"], .string("Alice"))
        XCTAssertEqual(fields["active"], .boolean(true))
        XCTAssertEqual(fields["count"], .integer(42))
        XCTAssertEqual(fields["score"], .double(3.14))
        XCTAssertEqual(fields["note"], .string("plain text"))
    }

    func testParseSimpleSupportsEqualsSeparator() throws {
        let fields = try FirestoreFieldsParser.parseSimple("role=admin")
        XCTAssertEqual(fields["role"], .string("admin"))
    }

    func testParseSimpleSkipsCommentsAndBlankLines() throws {
        let fields = try FirestoreFieldsParser.parseSimple("""
        # header
        status: ok

        // trailing
        """)
        XCTAssertEqual(fields["status"], .string("ok"))
        XCTAssertEqual(fields.count, 1)
    }

    func testParseJSONMapsPlainObject() throws {
        let fields = try FirestoreFieldsParser.parseJSON("""
        {"name":"Ada","active":false,"count":7,"ratio":1.5,"tags":["a","b"]}
        """)
        XCTAssertEqual(fields["name"], .string("Ada"))
        XCTAssertEqual(fields["active"], .boolean(false))
        XCTAssertEqual(fields["count"], .integer(7))
        XCTAssertEqual(fields["ratio"], .double(1.5))
        XCTAssertEqual(fields["tags"], .array([.string("a"), .string("b")]))
    }

    func testParseJSONEmptyReturnsEmptyMap() throws {
        XCTAssertTrue(try FirestoreFieldsParser.parseJSON("").isEmpty)
    }

    func testCollectionContextSplitsParentAndCollectionID() {
        let topLevel = FirestoreFieldsParser.collectionContext(for: "users")
        XCTAssertEqual(topLevel.collectionID, "users")
        XCTAssertNil(topLevel.parentDocumentPath)

        let nested = FirestoreFieldsParser.collectionContext(for: "users/abc/posts")
        XCTAssertEqual(nested.collectionID, "posts")
        XCTAssertEqual(nested.parentDocumentPath, "users/abc")
    }
}

final class FirestoreStructuredQueryFilterTests: XCTestCase {
    func testSavedQueryEncodesBooleanWhereClause() throws {
        let saved = SavedFirestoreQuery.make(
            title: "Active",
            collectionID: "users",
            fieldPath: "active",
            op: "EQUAL",
            stringValue: "true",
            filterValueKind: .bool,
            limit: 10
        )
        let query = saved.toStructuredQuery()
        XCTAssertEqual(query.`where`?.fieldFilter?.value, .boolean(true))

        let data = try JSONEncoder().encode(RunQueryRequest(structuredQuery: query))
        let json = String(data: data, encoding: .utf8) ?? ""
        XCTAssertTrue(json.contains("booleanValue"))
        XCTAssertTrue(json.contains("true"))
    }

    func testSavedQueryEncodesIntegerWhereClause() throws {
        let saved = SavedFirestoreQuery.make(
            title: "Tier",
            collectionID: "users",
            fieldPath: "tier",
            op: "EQUAL",
            stringValue: "3",
            filterValueKind: .number,
            limit: 5
        )
        let query = saved.toStructuredQuery()
        XCTAssertEqual(query.`where`?.fieldFilter?.value, .integer(3))
    }

    func testSavedQueryEncodesGreaterThanFilterAndDescendingOrder() throws {
        let saved = SavedFirestoreQuery.make(
            title: "Recent",
            collectionID: "posts",
            fieldPath: "score",
            op: "GREATER_THAN",
            stringValue: "10",
            filterValueKind: .number,
            orderField: "createdAt",
            descending: true,
            limit: 25
        )
        let query = saved.toStructuredQuery()
        XCTAssertEqual(query.`where`?.fieldFilter?.op, "GREATER_THAN")
        XCTAssertEqual(query.`where`?.fieldFilter?.value, .integer(10))
        XCTAssertEqual(query.orderBy?.count, 1)
        XCTAssertEqual(query.orderBy?.first?.field.fieldPath, "createdAt")
        XCTAssertEqual(query.orderBy?.first?.direction, "DESCENDING")

        let data = try JSONEncoder().encode(RunQueryRequest(structuredQuery: query))
        let json = String(data: data, encoding: .utf8) ?? ""
        XCTAssertTrue(json.contains("GREATER_THAN"))
        XCTAssertTrue(json.contains("createdAt"))
        XCTAssertTrue(json.contains("DESCENDING"))
    }
}
