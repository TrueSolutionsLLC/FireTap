# Test Plan

## Automated (XCTest) — current

Run: `xcodebuild -project FireTap.xcodeproj -scheme FireTap -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test`

| Area | Tests | File |
|---|---|---|
| PKCE generation | verifier length/charset, challenge = base64url(SHA256), uniqueness, state | `PKCETests` |
| OAuth callback | valid code, state mismatch rejection, missing state/code, denial, constant-time compare | `OAuthCallbackTests` |
| Networking | backoff bounds, Retry-After wins, Google error decoding, URL redaction, token decoding | `NetworkingTests` |
| Token refresh | refresh on empty cache, **concurrent dedup**, cached avoids refresh, force refresh, rotated refresh persisted, missing account | `TokenServiceTests` |
| Keychain | save/read/update/delete/all/deleteAll, missing → nil | `KeychainCredentialStoreTests` |
| Safe Mode | unlock success/fail/cancel, relock, **clock-based expiry**, configure relocks | `SafeModeTests` |
| StoreKit entitlement | Pro owned/not, free single-project gate, Pro any-project, write gating | `EntitlementsTests` |
| Firestore value types | all field types round-trip, nested map/array, timestamp, document decode | `FirestoreValueTests` |
| Cost Guard | read accumulation, negative ignored, large-read threshold, reset | `SessionUsageTests` |
| Audit trail | encrypted record/read round-trip, ordering, clear | `AuditTrailTests` |

**58 tests, 0 failures** at time of writing.

## Automated — planned (as modules land)

- Firestore pagination cursor behavior against the emulator.
- Firestore `updateTime` precondition rejection.
- Remote Config ETag mismatch handling.
- Log grouping / incident aggregation logic.
- Destructive-confirmation typed-match logic.
- Retry + cancellation behavior on `HTTPClient` (URLProtocol stub).
- Missing-permission (403) and partial/empty-project handling.

## UI tests

`FireTapUITests` verifies the app launches to a stable first screen. Planned: accessibility-identifier smoke tests for Welcome → consent, project list states, and light/dark + iPhone/iPad snapshots.

## Manual / integration (non-production project required)

- Real OAuth sign-in, token refresh after expiry, revoke, reauth.
- Firestore browse with read counting and large-read warning.
- Safe Mode unlock + relock on background.
- StoreKit purchase & restore using the local `.storekit` config.
- VoiceOver pass, Dynamic Type (XXXL), Reduce Motion, light/dark, iPhone + iPad split view.

## Emulators & test projects

- Use the **Firebase Local Emulator Suite** where it provides valid coverage (Firestore, Auth, RTDB).
- Use a **dedicated non-production Firebase project** for live API testing.
- **Never** run destructive automated tests against production.
