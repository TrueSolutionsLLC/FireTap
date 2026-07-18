import XCTest
@testable import FireTap

final class HostingModelTests: XCTestCase {
    func testDecodesSitesResponse() throws {
        let data = try loadFixture("hosting_sites")
        let response = try JSONDecoder().decode(ListHostingSitesResponse.self, from: data)
        let site = try XCTUnwrap(response.sites?.first)
        XCTAssertEqual(site.siteID, "demo")
        XCTAssertEqual(site.defaultUrl, "https://demo.web.app")
        XCTAssertEqual(site.type, "DEFAULT_SITE")
    }

    func testDecodesChannelsResponse() throws {
        let data = try loadFixture("hosting_channels")
        let response = try JSONDecoder().decode(ListHostingChannelsResponse.self, from: data)
        let channel = try XCTUnwrap(response.channels?.first)
        XCTAssertEqual(channel.channelID, "live")
        XCTAssertEqual(channel.url, "https://demo.web.app")
        XCTAssertEqual(channel.retainedReleaseCount, 10)
    }

    func testDecodesReleasesResponse() throws {
        let data = try loadFixture("hosting_releases")
        let response = try JSONDecoder().decode(ListHostingReleasesResponse.self, from: data)
        let release = try XCTUnwrap(response.releases?.first)
        XCTAssertEqual(release.type, "DEPLOY")
        XCTAssertEqual(release.message, "Deploy from CLI")
        XCTAssertEqual(release.version?.status, "FINALIZED")
    }

    private func loadFixture(_ name: String) throws -> Data {
        let bundle = Bundle(for: HostingModelTests.self)
        guard let url = bundle.url(forResource: name, withExtension: "json", subdirectory: "Hosting")
            ?? bundle.url(forResource: name, withExtension: "json", subdirectory: "Fixtures/Hosting")
            ?? bundle.url(forResource: name, withExtension: "json")
        else {
            throw NSError(domain: "HostingModelTests", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Missing fixture \(name).json"
            ])
        }
        return try Data(contentsOf: url)
    }
}
