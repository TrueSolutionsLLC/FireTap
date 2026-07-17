# Architecture

FireTap uses **MVVM** with a **protocol-oriented service layer** and **dependency injection**, all under Swift 6 strict concurrency (`SWIFT_STRICT_CONCURRENCY = complete`).

## Layers

```
┌──────────────────────────────────────────────────────────────┐
│ Views (SwiftUI)          Features/**/*View.swift               │
│   ↕ observe                                                    │
│ View Models (@MainActor @Observable)   Features/**/*ViewModel  │
│   ↕ call                                                       │
│ Services (protocols)     Services/**            ← injected     │
│   • ProjectsService      • FirestoreService     • …            │
│   ↕ use                                                        │
│ Core                                                           │
│   • GoogleAPIClient (auth + 401→refresh→retry)                 │
│   • HTTPClient (backoff, Retry-After, cancellation, typed err) │
│   • TokenService (actor: refresh dedup)                        │
│   • Keychain / CredentialStore                                 │
│   • SafeModeController / BiometricAuthenticator                │
│   • StoreManager / Entitlements                                │
│   • EncryptedAuditTrail (actor)                                │
│   • SessionUsage (Cost Guard)                                  │
└──────────────────────────────────────────────────────────────┘
```

## Composition root

`AppEnvironment` (`DI/AppEnvironment.swift`) is the single composition root. `AppEnvironment.live()` builds the production graph with live implementations; tests construct the same objects with in-memory / fake dependencies. `AppEnvironment` is injected through the SwiftUI `Environment` and is the UI's source of truth for session, selected project, Safe Mode, Pro entitlement, and Cost Guard usage.

A **single** `GoogleAPIClient` is shared across account switches: the underlying `TokenService` actor tracks the active account, so switching accounts changes the bearer token without rebuilding services.

## Concurrency

- UI state holders are `@MainActor @Observable` classes.
- Shared mutable infrastructure that isn't UI (token refresh, audit log) are `actor`s.
- Sendable value types (`HTTPRequest`, models, errors) cross isolation boundaries safely.
- **Token refresh is deduplicated** inside `TokenService`: concurrent callers awaiting a refresh share one in-flight `Task`, so a burst of 401s produces exactly one refresh (unit-tested in `TokenServiceTests`).

## Networking

- `HTTPClient` (an `actor`) performs requests with exponential backoff + full jitter, honors `Retry-After`, maps HTTP status → typed `APIError`, supports cancellation and timeouts, and exposes `ETag` for preconditions.
- `GoogleAPIClient` layers authorization on top: it attaches the active bearer token and, on a `401`, performs exactly one forced refresh + retry before surfacing `.unauthorized`.
- **Redacted logging** (`RedactedLog`) never logs tokens, authorization headers, bodies, document contents, or emails; URLs have query values masked.

## Authentication

- `PKCEChallenge` (RFC 7636, S256) + random `state`.
- `GoogleOAuthClient` builds the authorization URL and performs code exchange / refresh / revoke / userinfo. No client secret.
- `WebAuthenticator` wraps `ASWebAuthenticationSession` (ephemeral session; the system browser holds the password).
- `OAuthCallback` validates `state` with a constant-time comparison and extracts the code.
- `AccountManager` (`@MainActor`) orchestrates multi-account sign-in, switching, disconnect (with revocation), and local-credential deletion.

## Safe Mode

`SafeModeController` gates writes: production opens read-only; unlocking requires biometrics; the unlock relocks after an inactivity window and immediately on backgrounding (`scenePhase` in `FireTapApp`). Destructive actions must additionally pass a typed-confirmation flow and are recorded in the encrypted `AuditTrail`.

## Testing seams

Every external dependency is a protocol: `OAuthClient`, `CredentialStoring`, `HTTPTransport`, `TokenProviding`, `BiometricAuthenticating`, `ProjectsService`, `FirestoreService`, `AuditLogging`. Production uses live implementations; tests inject deterministic fakes (`Tests/FireTapTests/Support/Fakes.swift`). **No fake data ships in the app target.**

## Folder map

```
FireTap/
  App/            App entry + RootView
  Configuration/  AppConfig (reads xcconfig via Info.plist)
  DesignSystem/   Theme, Typography, Components, StateViews
  Core/           Networking, Security, Persistence, Logging, AsyncPhase
  Auth/           PKCE, OAuth client, WebAuthenticator, TokenService, AccountManager
  Services/       Protocol-typed API clients (Projects, Firestore, …)
  Domain/Models/  Codable models (FirebaseProject, Firestore*, AuditEntry, …)
  SafeMode/       SafeModeController
  StoreKit/       StoreManager, Entitlements
  Audit/          EncryptedAuditTrail
  CostGuard/      SessionUsage
  DI/             AppEnvironment (composition root)
  Features/       MVVM screens
```
