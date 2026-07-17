# FireTap — Firebase Admin

**Fix Firebase from your phone.**

*Firestore, Auth & Functions* — a native **iOS/iPadOS** console for securely managing **Firebase / Google Cloud** projects: inspect, monitor, investigate, and perform carefully guarded administrative actions from your phone or iPad.

- **Platform:** Swift 6 · SwiftUI · iOS/iPadOS 17+ (built with the iOS 26 SDK / Xcode 26)
- **Architecture:** MVVM + protocol-oriented services + dependency injection, strict concurrency (`complete`)
- **Privacy:** Your project data travels **directly** between your device and Google APIs. Nothing is routed through an app-owned server. Refresh tokens live only in the iOS Keychain.
- **Bundle id:** `com.truesolutions.firetap` · **Version:** 1.0 (build 1)

> FireTap is an independent, third-party tool. It is **not** affiliated with, endorsed by, or sponsored by Google or Apple. "Firebase" and "Google Cloud" are trademarks of Google LLC, used here only descriptively; no official Firebase branding or logos are used.
>
> Product name, bundle id, OAuth client, and StoreKit product id are all centralized (see [Configuration](#configuration)) so they can be changed without touching Swift code.

---

## Requirements

- macOS with **Xcode 26** (or newer)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) to generate the `.xcodeproj` (the project is defined in `project.yml` and the `.xcodeproj` is git-ignored)
- A Google Cloud project with an **OAuth 2.0 iOS client** (see [docs/OAUTH_SETUP.md](docs/OAUTH_SETUP.md))
- For live testing: a **dedicated non-production Firebase test project** — never test destructive actions against production

## Getting started

```bash
# 1. Install XcodeGen (Homebrew, Mint, or the release binary)
brew install xcodegen        # or: mint install yonaskolb/XcodeGen

# 2. Create your secrets file from the template and fill in your OAuth client
cp Config/Secrets.xcconfig.example Config/Secrets.xcconfig
$EDITOR Config/Secrets.xcconfig

# 3. Generate the Xcode project
xcodegen generate

# 4. Open and run
open FireTap.xcodeproj
```

Until you add a real OAuth client id, the app runs and shows an **honest "sign-in not configured"** state instead of a broken button. There is **no mock data** anywhere in the shipping target — every screen shows live data or an honest configuration / loading / permission / empty / error state.

## Building & testing from the command line

```bash
xcodegen generate
xcodebuild -project FireTap.xcodeproj -scheme FireTap \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build

xcodebuild -project FireTap.xcodeproj -scheme FireTap \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```

## Configuration

All product identity lives in `Config/*.xcconfig` and is surfaced to Swift through `AppConfig`:

| Value | Where to change |
|---|---|
| Display name | `Config/Shared.xcconfig` → `APP_DISPLAY_NAME` |
| Bundle id | `Config/Shared.xcconfig` → `APP_BUNDLE_ID` |
| StoreKit Pro product id | `Config/Shared.xcconfig` → `STOREKIT_PRO_PRODUCT_ID` |
| OAuth client id / redirect scheme | `Config/Secrets.xcconfig` (git-ignored) |
| Support / privacy / terms URLs | `Config/Shared.xcconfig` |

## Security model (summary)

- **Authorization Code Flow with PKCE** via `ASWebAuthenticationSession` — the app never sees your Google password and never requests one.
- **No client secret** (native iOS OAuth clients are public clients).
- Refresh tokens are stored **only** in the iOS Keychain (`AfterFirstUnlockThisDeviceOnly`, not synced).
- No service-account JSON is ever imported or stored.
- **Face ID / App Lock** via `LocalAuthentication`; **Production Safe Mode** opens production projects read-only and relocks on inactivity/backgrounding.
- Networking never logs tokens, authorization headers, document contents, or emails.

See [docs/SECURITY_THREAT_MODEL.md](docs/SECURITY_THREAT_MODEL.md).

## Module status

See the honest, living status table in [docs/IMPLEMENTATION_CHECKLIST.md](docs/IMPLEMENTATION_CHECKLIST.md) and the API mapping in [docs/API_COVERAGE.md](docs/API_COVERAGE.md).

## Documentation

- [Architecture](docs/ARCHITECTURE.md)
- [OAuth setup & Google verification checklist](docs/OAUTH_SETUP.md)
- [API coverage matrix](docs/API_COVERAGE.md)
- [Security threat model](docs/SECURITY_THREAT_MODEL.md)
- [Test plan](docs/TEST_PLAN.md)
- [Accessibility audit](docs/ACCESSIBILITY_AUDIT.md)
- [Privacy policy (template)](docs/PRIVACY_POLICY.md) · [Terms of use (template)](docs/TERMS_OF_USE.md) · [Support (template)](docs/SUPPORT.md)
- [App Privacy guidance](docs/APP_PRIVACY.md) · [App Store metadata & review notes](docs/APP_STORE_METADATA.md)
- [TestFlight checklist](docs/TESTFLIGHT_CHECKLIST.md) · [Release checklist](docs/RELEASE_CHECKLIST.md)
- [Implementation checklist (status)](docs/IMPLEMENTATION_CHECKLIST.md)

## License / ownership

Private project scaffold generated for the app owner. Replace this section with your chosen license before distribution.
