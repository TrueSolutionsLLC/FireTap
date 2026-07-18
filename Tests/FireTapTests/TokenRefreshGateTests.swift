import XCTest
@testable import FireTap

final class TokenRefreshGateTests: XCTestCase {
    func testConcurrentCallsShareSingleOperation() async throws {
        let gate = TokenRefreshGate()
        let counter = LockedCounter()

        let values = try await withThrowingTaskGroup(of: String.self) { group in
            for index in 0..<8 {
                group.addTask {
                    try await gate.run {
                        counter.increment()
                        try await Task.sleep(nanoseconds: 100_000_000)
                        return "token-\(index)"
                    }
                }
            }
            var results: [String] = []
            for try await value in group { results.append(value) }
            return results
        }

        XCTAssertEqual(counter.value, 1)
        XCTAssertEqual(values.count, 8)
        XCTAssertTrue(values.allSatisfy { $0 == values.first })
    }
}

private final class LockedCounter: @unchecked Sendable {
    private let lock = NSLock()
    private(set) var value = 0
    func increment() {
        lock.lock()
        value += 1
        lock.unlock()
    }
}

final class FireTapDeepLinkParserTests: XCTestCase {
    func testParsesProjectModuleURL() {
        let url = URL(static: "firetap://project/my-app/module/firestore")
        let link = FireTapDeepLinkParser.parse(url)
        XCTAssertEqual(link?.projectID, "my-app")
        XCTAssertEqual(link?.moduleRawValue, "firestore")
        XCTAssertEqual(link?.module, .firestore)
    }

    func testRejectsNonFireTapScheme() {
        let url = URL(static: "https://example.com/project/foo/module/bar")
        XCTAssertNil(FireTapDeepLinkParser.parse(url))
    }
}
