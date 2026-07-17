# Security Threat Model

## Assets

- OAuth **refresh tokens** (long-lived, high value).
- OAuth **access tokens** (short-lived, in-memory).
- Customer **project data** (Firestore documents, users, logs, storage objects).
- The **local audit trail**.

## Trust boundaries

- Device ↔ Google APIs (TLS, direct). **No app-owned server is in the path.**
- App ↔ iOS Keychain / Secure Enclave-backed biometrics.
- App ↔ System browser (`ASWebAuthenticationSession`) for the password step.

## Controls

| Threat | Control |
|---|---|
| Password phishing by the app | App never sees the password; sign-in happens in the system browser. |
| Client-secret leakage | Public iOS OAuth client — **no secret exists**. |
| Authorization code interception | **PKCE (S256)** binds the code to the device. |
| CSRF / response injection | Random `state`, validated with a **constant-time** comparison; mismatches are rejected. |
| Token theft at rest | Refresh tokens in Keychain (`AfterFirstUnlockThisDeviceOnly`, not iCloud-synced). Never in UserDefaults. |
| Token theft via logs | `RedactedLog` never logs tokens, auth headers, bodies, emails; query values masked. |
| Duplicate/racing refresh | `TokenService` actor deduplicates concurrent refreshes. |
| Unauthorized device access | Face ID / App Lock; **Production Safe Mode** read-only by default, relocks on inactivity/backgrounding. |
| Accidental destructive action | Exact target shown, typed confirmation, before/after diff, encrypted audit trail, idempotency keys. |
| Overwriting concurrent edits | `updateTime` / `ETag` preconditions → `preconditionFailed`. |
| Runaway billable reads | Cost Guard counts reads, warns before large reads, never auto-loads whole collections. |
| Service-account key sprawl | Service-account JSON is **never** imported or stored. |
| Data exfiltration to third parties | No analytics/ad SDKs; no customer data leaves the device except to Google. |

## Residual risks / assumptions

- A jailbroken or compromised device can undermine Keychain and biometric guarantees.
- Google account compromise is out of scope (mitigated by the user's Google security).
- Scope breadth (`cloud-platform`) grants wide access; the app mitigates via read-only defaults, Safe Mode, and per-action confirmation, but the grant itself is broad. Tighten scopes if your use case allows.

## Reporting

Security issues: see the contact in `docs/SUPPORT.md`. Please do not file public issues for vulnerabilities.
