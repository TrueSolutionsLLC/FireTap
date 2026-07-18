import XCTest
@testable import FireTap

final class StorageUploadTests: XCTestCase {
    func testContentRangeHeaderFormatting() {
        XCTAssertEqual(HTTPContentRange.header(start: 0, end: 262_143, total: 1_048_576), "bytes 0-262143/1048576")
        XCTAssertEqual(HTTPContentRange.header(start: 262_144, end: 524_287, total: 1_048_576), "bytes 262144-524287/1048576")
        XCTAssertEqual(HTTPContentRange.header(start: 0, end: 99, total: 100), "bytes 0-99/100")
    }

    func testResumableUploadCompletesAcrossChunks() async throws {
        let payload = Data(
            count: LiveStorageService.simpleUploadLimitBytes + LiveStorageService.resumableChunkBytes + 1
        )
        let objectJSON = """
        {"name":"folder/file.bin","bucket":"demo.appspot.com","size":"\(payload.count)"}
        """.data(using: .utf8)!

        var putCount = 0
        MockURLProtocol.requestHandler = { request in
            let url = request.url?.absoluteString ?? ""
            if url.contains("uploadType=resumable") {
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: ["Location": "https://storage.googleapis.com/upload/session/chunk"]
                )!
                return (response, Data())
            }
            if request.httpMethod == "PUT", url.contains("/upload/session/chunk") {
                putCount += 1
                let range = request.value(forHTTPHeaderField: "Content-Range") ?? ""
                let isFinal = range.hasSuffix("/\(payload.count)") && range.contains("-\(payload.count - 1)/")
                let status = isFinal ? 200 : 308
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: status,
                    httpVersion: nil,
                    headerFields: nil
                )!
                return (response, isFinal ? objectJSON : Data())
            }
            throw URLError(.badURL)
        }

        let session = FakeGoogleSignInSession()
        session.seed(.fixture())
        let api = GoogleAPIClient(
            transport: HTTPClient(session: MockURLProtocol.session(), backoff: Backoff(maxRetries: 0)),
            tokenProvider: GoogleSignInTokenProvider(session: session)
        )
        let service = LiveStorageService(api: api)
        let object = try await service.uploadObject(
            bucket: "demo.appspot.com",
            name: "folder/file.bin",
            contentType: "application/octet-stream",
            data: payload
        )
        XCTAssertEqual(object.name, "folder/file.bin")
        XCTAssertEqual(putCount, 42)
    }

    override func tearDown() {
        MockURLProtocol.requestHandler = nil
        super.tearDown()
    }
}
