import XCTest
@testable import FireTap

final class StorageObjectTests: XCTestCase {

    func testDecodesObjectListingWithFoldersAndFiles() throws {
        let json = """
        {
          "prefixes": ["images/", "docs/"],
          "items": [
            { "name": "images/", "bucket": "demo.appspot.com", "size": "0" },
            { "name": "images/logo.png", "bucket": "demo.appspot.com", "contentType": "image/png", "size": "20480", "updated": "2026-01-02T03:04:05Z" }
          ],
          "nextPageToken": "PAGE2"
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(ListObjectsResponse.self, from: json)
        XCTAssertEqual(response.prefixes, ["images/", "docs/"])
        XCTAssertEqual(response.nextPageToken, "PAGE2")

        let file = try XCTUnwrap(response.items?.first { $0.name == "images/logo.png" })
        XCTAssertEqual(file.byteCount, 20480)
        XCTAssertEqual(file.displayName(strippingPrefix: "images/"), "logo.png")
        XCTAssertNotNil(file.updatedDate)
        XCTAssertEqual(file.contentType, "image/png")
    }

    func testHumanReadableSize() {
        XCTAssertEqual(StorageFormat.size(nil), "—")
        XCTAssertFalse(StorageFormat.size(1_048_576).isEmpty)
    }

    func testDecodesBucketList() throws {
        let json = """
        { "items": [ { "name": "demo.appspot.com", "location": "US", "storageClass": "STANDARD" } ] }
        """.data(using: .utf8)!
        let response = try JSONDecoder().decode(ListBucketsResponse.self, from: json)
        XCTAssertEqual(response.items?.first?.name, "demo.appspot.com")
        XCTAssertEqual(response.items?.first?.location, "US")
    }
}
