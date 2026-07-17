import XCTest
@testable import FireTap

final class FirestoreValueTests: XCTestCase {
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    private func roundTrip(_ json: String) throws -> FirestoreValue {
        let value = try decoder.decode(FirestoreValue.self, from: Data(json.utf8))
        let data = try encoder.encode(value)
        return try decoder.decode(FirestoreValue.self, from: data)
    }

    func testStringValue() throws {
        XCTAssertEqual(try roundTrip(#"{"stringValue":"hello"}"#), .string("hello"))
    }

    func testIntegerValueIsStringInWire() throws {
        XCTAssertEqual(try roundTrip(#"{"integerValue":"42"}"#), .integer(42))
    }

    func testDoubleValue() throws {
        XCTAssertEqual(try roundTrip(#"{"doubleValue":3.5}"#), .double(3.5))
    }

    func testBooleanValue() throws {
        XCTAssertEqual(try roundTrip(#"{"booleanValue":true}"#), .boolean(true))
    }

    func testNullValue() throws {
        XCTAssertEqual(try roundTrip(#"{"nullValue":null}"#), .null)
    }

    func testGeoPointValue() throws {
        let value = try roundTrip(#"{"geoPointValue":{"latitude":1.5,"longitude":-2.5}}"#)
        XCTAssertEqual(value, .geoPoint(latitude: 1.5, longitude: -2.5))
    }

    func testReferenceValue() throws {
        XCTAssertEqual(try roundTrip(#"{"referenceValue":"projects/p/databases/(default)/documents/c/d"}"#),
                       .reference("projects/p/databases/(default)/documents/c/d"))
    }

    func testArrayValue() throws {
        let value = try roundTrip(#"{"arrayValue":{"values":[{"integerValue":"1"},{"stringValue":"x"}]}}"#)
        XCTAssertEqual(value, .array([.integer(1), .string("x")]))
    }

    func testNestedMapValue() throws {
        let json = #"{"mapValue":{"fields":{"a":{"integerValue":"1"},"b":{"mapValue":{"fields":{"c":{"booleanValue":false}}}}}}}"#
        let value = try roundTrip(json)
        XCTAssertEqual(value, .map(["a": .integer(1), "b": .map(["c": .boolean(false)])]))
    }

    func testTimestampValueRoundTrips() throws {
        let value = try roundTrip(#"{"timestampValue":"2024-01-02T03:04:05.123Z"}"#)
        if case .timestamp = value { } else { XCTFail("expected timestamp") }
    }

    func testDocumentDecoding() throws {
        let json = """
        { "name": "projects/p/databases/(default)/documents/orders/ord_1",
          "fields": { "total": { "integerValue": "1299" } },
          "createTime": "2024-01-01T00:00:00Z", "updateTime": "2024-01-02T00:00:00Z" }
        """
        let doc = try decoder.decode(FirestoreDocument.self, from: Data(json.utf8))
        XCTAssertEqual(doc.documentID, "ord_1")
        XCTAssertEqual(doc.relativePath, "orders/ord_1")
        XCTAssertEqual(doc.fields?["total"], .integer(1299))
    }
}
