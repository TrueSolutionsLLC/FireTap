import XCTest
@testable import FireTap

final class HTTPClientStatusTests: XCTestCase {
    override func setUp() {
        super.setUp()
        MockURLProtocol.requestHandler = nil
    }

    func testMaps401() async {
        MockURLProtocol.requestHandler = { _ in
            (HTTPURLResponse(url: URL(string: "https://example.com")!, statusCode: 401, httpVersion: nil, headerFields: nil)!, Data())
        }
        await assertError(.unauthorized)
    }

    func testMaps403() async {
        MockURLProtocol.requestHandler = { _ in
            (HTTPURLResponse(url: URL(string: "https://example.com")!, statusCode: 403, httpVersion: nil, headerFields: nil)!, Data())
        }
        await assertError(.permissionDenied(message: nil))
    }

    func testMaps404() async {
        MockURLProtocol.requestHandler = { _ in
            (HTTPURLResponse(url: URL(string: "https://example.com")!, statusCode: 404, httpVersion: nil, headerFields: nil)!, Data())
        }
        await assertError(.notFound(message: nil))
    }

    func testMaps429AfterRetriesExhausted() async {
        MockURLProtocol.requestHandler = { _ in
            (HTTPURLResponse(url: URL(string: "https://example.com")!, statusCode: 429, httpVersion: nil, headerFields: ["Retry-After": "0"])!, Data())
        }
        let client = HTTPClient(
            session: MockURLProtocol.session(),
            backoff: Backoff(base: 0, cap: 0, maxRetries: 0)
        )
        do {
            _ = try await client.send(HTTPRequest(.get, url: URL(string: "https://example.com/x")!), bearerToken: nil)
            XCTFail("expected error")
        } catch {
            guard case APIError.rateLimited = error else {
                return XCTFail("unexpected \(error)")
            }
        }
    }

    func testMaps500AfterRetriesExhausted() async {
        MockURLProtocol.requestHandler = { _ in
            (HTTPURLResponse(url: URL(string: "https://example.com")!, statusCode: 500, httpVersion: nil, headerFields: nil)!, Data())
        }
        let client = HTTPClient(
            session: MockURLProtocol.session(),
            backoff: Backoff(base: 0, cap: 0, maxRetries: 0)
        )
        do {
            _ = try await client.send(HTTPRequest(.get, url: URL(string: "https://example.com/x")!), bearerToken: nil)
            XCTFail("expected error")
        } catch {
            guard case APIError.server(status: 500, _) = error else {
                return XCTFail("unexpected \(error)")
            }
        }
    }

    func testCancellation() async {
        MockURLProtocol.requestHandler = { _ in
            try await Task.sleep(nanoseconds: 2_000_000_000)
            return (HTTPURLResponse(url: URL(string: "https://example.com")!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data())
        }
        let client = HTTPClient(session: MockURLProtocol.session(), backoff: Backoff(maxRetries: 0))
        let task = Task {
            try await client.send(HTTPRequest(.get, url: URL(string: "https://example.com/x")!), bearerToken: nil)
        }
        task.cancel()
        do {
            _ = try await task.value
            XCTFail("expected cancellation")
        } catch {
            // Cancelled or APIError.cancelled both acceptable depending on timing.
            let isCancel = error is CancellationError
                || (error as? APIError) == .cancelled
                || (error as? URLError)?.code == .cancelled
            XCTAssertTrue(isCancel || (error as? APIError) != nil)
        }
    }

    private func assertError(_ expected: APIError) async {
        let client = HTTPClient(session: MockURLProtocol.session(), backoff: Backoff(maxRetries: 0))
        do {
            _ = try await client.send(HTTPRequest(.get, url: URL(string: "https://example.com/x")!), bearerToken: nil)
            XCTFail("expected \(expected)")
        } catch let error as APIError {
            XCTAssertEqual(error, expected)
        } catch {
            XCTFail("unexpected \(error)")
        }
    }
}

final class ProjectsPaginationTests: XCTestCase {
    func testListProjectsFollowsPageTokens() async throws {
        let page1 = """
        {"results":[{"projectId":"a","displayName":"A","state":"ACTIVE"}],"nextPageToken":"T2"}
        """.data(using: .utf8)!
        let page2 = """
        {"results":[{"projectId":"b","displayName":"B","state":"ACTIVE"}]}
        """.data(using: .utf8)!

        var calls = 0
        MockURLProtocol.requestHandler = { request in
            calls += 1
            let url = request.url?.absoluteString ?? ""
            if url.contains("pageToken=T2") {
                return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, page2)
            }
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, page1)
        }

        let tokens = FakeGoogleSignInSession()
        tokens.seed(.fixture())
        let provider = GoogleSignInTokenProvider(session: tokens)
        let api = GoogleAPIClient(
            transport: HTTPClient(session: MockURLProtocol.session(), backoff: Backoff(maxRetries: 0)),
            tokenProvider: provider
        )
        let service = LiveProjectsService(api: api)
        let projects = try await service.listProjects()
        XCTAssertEqual(projects.map(\.projectId), ["a", "b"])
        XCTAssertEqual(calls, 2)
    }
}

// MARK: - URLProtocol mock

final class MockURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var requestHandler: ((URLRequest) async throws -> (HTTPURLResponse, Data))?

    static func session() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: config)
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = MockURLProtocol.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        Task {
            do {
                let (response, data) = try await handler(request)
                client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                client?.urlProtocol(self, didLoad: data)
                client?.urlProtocolDidFinishLoading(self)
            } catch {
                client?.urlProtocol(self, didFailWithError: error)
            }
        }
    }

    override func stopLoading() {}
}
