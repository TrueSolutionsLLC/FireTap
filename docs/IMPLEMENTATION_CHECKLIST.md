# Implementation Checklist (living status)

Honest status of the build. ✅ done · 🟡 partial/foundation present · ⬜ not started.

## Foundation
- ✅ Xcode project (XcodeGen), Swift 6, strict concurrency `complete`, iOS 17+ / iOS 26 SDK
- ✅ Centralized config (product name, bundle id, OAuth, StoreKit id) via xcconfig + `AppConfig`
- ✅ `Secrets.xcconfig.example`; real `Secrets.xcconfig` git-ignored
- ✅ Design system from Figma tokens (light + dark, SF Symbols, Dynamic Type)
- ✅ Honest state components (loading skeletons, empty, error, permission, not-configured)
- ✅ App icon asset

## Security & session
- ✅ Official **Google Sign-In SDK** (Authorization Code + PKCE via SDK; no client secret)
- ✅ Tokens only in SDK Keychain-backed storage (never UserDefaults)
- ✅ Phase 1 scopes: identity + `firebase.readonly`; write scopes deferred to incremental auth
- ✅ Session restore (`restorePreviousSignIn`), auto token refresh, sign-out / disconnect / delete local
- ✅ Account switcher (different Google account) + connected-account display
- ✅ Scope consent screen explaining each permission before authorization
- ✅ Face ID / App Lock (`LocalAuthentication`)
- ✅ Production Safe Mode: read-only default, biometric unlock, inactivity + background relock
- ✅ Encrypted local audit trail (AES-GCM, key in Keychain)

## Networking
- ✅ `URLSession` + Codable, typed `APIError`
- ✅ Exponential backoff + jitter, `Retry-After`, cancellation, timeouts
- ✅ ETag/precondition surfacing (`preconditionFailed`)
- ✅ Redacted logging (no tokens/headers/bodies/emails)

## Monetization
- ✅ StoreKit 2 manager (load product, purchase, restore, entitlement sync)
- ✅ Local `.storekit` config ($24.99 lifetime non-consumable), centralized product id
- ✅ Free = read-only one project; Pro = multiple projects + writes (gating logic + tests)
- ✅ App not hidden behind paywall

## Modules
- ✅ **Phase 1 Projects vertical slice:** live Firebase Management API list (paginated), search, active-first sort, pin, environment labels, project number + lifecycle, pull-to-refresh, last-project restore with access check, account switcher, honest empty/error/offline states
- 🟡 Command Center: live project facts + apps; metrics via Monitoring pending; honest metric state
- ✅ Firestore: live databases default, collections, **paginated** documents with **read counting** + large-read warning, document detail (fields tree + JSON), copy path/reference, timestamps
- 🟡 Firestore writes: guarded framework designed; mutation endpoints pending
- 🟡 Authentication: live paginated user list, search by email/phone/UID, total count, and full read-only detail (providers, verification, timestamps, custom claims); guarded write actions (disable/delete/reset/claims) planned
- 🟡 Cloud Storage: live bucket list and folder-scoped, paginated object browser with metadata detail; download/preview/write planned (large files never auto-download)
- ⬜ Functions, Logs, Realtime DB, Remote Config, App Check, Rules, Hosting, App Distribution, IAM, Extensions, FCM, Billing — honest states; service clients to be added incrementally
- 🟡 Incident Center: honest aggregation state pending source modules
- 🟡 Cost Guard: session read counting live; budget/quota series pending Billing/Monitoring

## Navigation & UX
- ✅ Four tabs (Command Center / Data / Activity / Settings)
- ✅ Data service directory (searchable)
- ✅ iPhone + iPad supported (device family 1,2)
- ⬜ Command palette, iPad keyboard shortcuts (planned)

## Testing
- ✅ 58 unit tests passing (PKCE, OAuth, networking, token refresh dedup, keychain, Safe Mode, entitlements, Firestore types, cost guard, audit)
- 🟡 UI tests: launch smoke; more planned
- ⬜ Emulator-based integration tests

## Release docs
- ✅ README, ARCHITECTURE, OAUTH_SETUP (+verification), API_COVERAGE, SECURITY_THREAT_MODEL, TEST_PLAN
- ✅ PrivacyInfo.xcprivacy, APP_PRIVACY, PRIVACY_POLICY, TERMS_OF_USE, SUPPORT
- ✅ APP_STORE_METADATA, ACCESSIBILITY_AUDIT, TESTFLIGHT_CHECKLIST, RELEASE_CHECKLIST

## Definition-of-Done items still requiring the owner
- ⬜ Real Google OAuth client id + consent screen verification (owner's Google Cloud)
- ⬜ Live testing against a dedicated non-production Firebase project
- ⬜ Apple Developer signing, archive, TestFlight, App Store submission
