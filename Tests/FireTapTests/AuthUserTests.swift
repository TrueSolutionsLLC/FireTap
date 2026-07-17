import XCTest
@testable import FireTap

final class AuthUserTests: XCTestCase {

    func testDecodesBatchGetResponse() throws {
        let json = """
        {
          "users": [
            {
              "localId": "abc123",
              "email": "dev@example.com",
              "emailVerified": true,
              "displayName": "Dev User",
              "phoneNumber": "+15551234567",
              "disabled": false,
              "createdAt": "1700000000000",
              "lastLoginAt": "1700100000000",
              "validSince": "1700000000",
              "providerUserInfo": [
                { "providerId": "google.com", "email": "dev@example.com" },
                { "providerId": "password", "email": "dev@example.com" }
              ],
              "customAttributes": "{\\"role\\":\\"admin\\",\\"level\\":3}"
            }
          ],
          "nextPageToken": "TOKEN2"
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(DownloadAccountResponse.self, from: json)
        let user = try XCTUnwrap(response.users?.first)

        XCTAssertEqual(response.nextPageToken, "TOKEN2")
        XCTAssertEqual(user.localId, "abc123")
        XCTAssertEqual(user.primaryLabel, "Dev User")
        XCTAssertEqual(user.emailVerified, true)
        XCTAssertFalse(user.isDisabled)
        XCTAssertFalse(user.isAnonymous)
        XCTAssertEqual(user.providerLabels, ["Google", "Email/Password"])

        // Timestamps
        XCTAssertEqual(user.createdDate?.timeIntervalSince1970 ?? 0, 1_700_000_000, accuracy: 0.001)
        XCTAssertEqual(user.lastSignInDate?.timeIntervalSince1970 ?? 0, 1_700_100_000, accuracy: 0.001)
        XCTAssertEqual(user.validSinceDate?.timeIntervalSince1970 ?? 0, 1_700_000_000, accuracy: 0.001)

        // Custom claims parsed + sorted
        let claims = user.customClaims
        XCTAssertEqual(claims.map(\.key), ["level", "role"])
        XCTAssertEqual(claims.first(where: { $0.key == "role" })?.value, "admin")
    }

    func testAnonymousUserLabel() {
        let user = AuthUser(
            localId: "anon1", email: nil, emailVerified: nil, displayName: nil,
            photoUrl: nil, phoneNumber: nil, disabled: nil, providerUserInfo: [],
            customAttributes: nil, tenantId: nil,
            createdAt: nil, lastLoginAt: nil, lastRefreshAt: nil, validSince: nil
        )
        XCTAssertTrue(user.isAnonymous)
        XCTAssertEqual(user.primaryLabel, "Anonymous user")
        XCTAssertTrue(user.customClaims.isEmpty)
    }

    func testSearchClassification() {
        XCTAssertEqual(AuthUsersViewModel.classify("dev@example.com"), .email("dev@example.com"))
        XCTAssertEqual(AuthUsersViewModel.classify("+15551234567"), .phone("+15551234567"))
        XCTAssertEqual(AuthUsersViewModel.classify("15551234567"), .phone("+15551234567"))
        XCTAssertEqual(AuthUsersViewModel.classify("abcDEF123xyz"), .uid("abcDEF123xyz"))
    }
}
