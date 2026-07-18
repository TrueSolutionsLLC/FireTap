# BUILD_STATUS

Living status of FireTap multi-phase build. Updated after every phase gate.

**Product:** FireTap: Firebase Admin  
**Display name:** FireTap  
**Version / build:** 1.0 (1)  
**Last updated:** 2026-07-17 (continuation: write scopes, favorites wiring, Hosting drill-down, Functions invoke, query ops, resumable upload)

## Overall

| Phase | Status | Gate |
|-------|--------|------|
| 1 Auth + Projects | 🟡 Code complete; live OAuth externally blocked | Continue |
| 2 Firestore | ✅ + subcollections, query ops, orderBy | Continue |
| 3 Auth management | ✅ + WriteGate requests write scopes | Continue |
| 4 Functions / Logs / Incidents | ✅ + safe HTTP invoke for known HTTPS URL | Continue |
| 5 Storage + RTDB | ✅ + resumable upload (≤100 MB in-memory) | Continue |
| 6 Remote Config / Hosting / … | ✅ + Hosting channels/releases | Continue |
| 7 IAM / FCM / Cost Guard | ✅ | Continue |
| 8 Command Center | ✅ + module recently-viewed wiring | Continue |
| 9 Safety / Privacy | ✅ | Continue |
| 10 StoreKit | ✅ | Continue |
| 11 A11y / Performance | ✅ | Continue |
| 12 Complete testing | ✅ **123 unit + 2 UI** | Continue |
| 13 Final audit | ✅ | Continue |
| 14 Release prep | ✅ Docs; external config still required | **BLOCKED** |

**Release readiness:** see `RELEASE_AUDIT.md` → **BLOCKED** (OAuth secrets, signing, hosted legal URLs, ASC product).

### Continuation completed (post–Phase 14 pass)
- `WriteGate.ensureUnlocked` now requests incremental Google write scopes before biometric unlock
- `ServiceModuleView` records recently viewed modules; Firestore docs support favorite + subcollection browse
- Hosting: sites → channels → releases
- Functions: detail + manual HTTP invoke only for API-known URL (no auto-execute)
- Firestore query: operators beyond EQUAL + orderBy
- Storage: resumable uploads with Location/Content-Range; 100 MB hard cap
- Tests: **125 total** (123 unit + 2 UI), clean build, no FireTap source warnings

---

## Phase 1 — Authentication and Projects

### Completed requirements
- Google Sign-In SDK (PKCE via SDK), no client secret
- Initial scopes: identity + `firebase.readonly`; write scopes deferred
- Session restore, token refresh (deduplicated), sign-out / disconnect / delete local
- Account switcher UI
- Live Firebase Management API project list (paginated)
- Search, active-first sort, pin, environment labels, project number + lifecycle
- Last-project restore with access check
- Free-tier single-project gate with Pro alert
- Version remains 1.0 build 1

### Tests executed
- Full unit suite including AccountManager, GoogleSignInTokenProvider, projects, HTTP

### Test results
- **113 tests, 0 failures** (latest clean run)

### Live API verification performed
- Not possible yet — `Config/Secrets.xcconfig` has no real OAuth client ID

### Known limitations
- Google Sign-In iOS keeps one active SDK session; switching accounts uses interactive re-auth
- Live end-to-end sign-in / project load not verified against a real Google account

### Remaining work
- Owner must configure OAuth iOS client (see `MANUAL_SETUP.md`)

### External blockers
- **OAuth client ID + reversed URL scheme** in `Secrets.xcconfig`
- ~~Apple Developer Team for device installs~~ ✅ `2P268A8J66`
- Google OAuth consent / verification for public release

### Files changed (Phase 1)
- Auth: Google Sign-In session, TokenRefreshGate, AccountManager
- Projects: ordering, picker, last-project restore

---

## Phase 2 — Firestore

### Completed
- Database / collection / document browse with pagination
- runQuery + query builder UI (equality filter), saved queries (local)
- Create / patch (updateMask + updateTime precondition) / delete
- Value types via FirestoreValue decoder; fields + JSON views
- Conflict handling (412) with reload; typed delete; WriteGate + Safe Mode
- Session read/write counters; billing disclaimer on query results
- Undo not offered when unsafe (documented in UI)

### Tests
- FirestoreFieldsParserTests, structured query encoding tests

### Live API verification
- Blocked on OAuth

### Limitations
- Query builder: EQUAL only; single-page limit; no composite filters UI
- Storage of saved queries by collection id (not full parent path)

---

## Phase 3 — Auth management

### Completed
- Paginated user list + lookup search
- Detail: providers, dates, disabled, claims (read)
- Enable/disable, delete (typed confirm), custom claims edit with before/after diff
- Password reset email via `accounts:sendOobCode` (never handles passwords)

### Limitations
- Needs Identity Toolkit admin write scopes (incremental auth)
- Tenant-specific configs may 403 — surfaced as API errors

---

## Phase 4 — Functions, Logging, Monitoring, Incidents

### Completed
- Gen1/Gen2 function list
- Logs with severity filter, grouping, expandable payloads
- Monitoring metrics view (honest empty/delayed)
- Incident Center aggregating functions errors, ERROR logs, audit actions

### Limitations
- No automatic function execution; no fabricated deployment controls
- Metrics only when Cloud Monitoring returns series

---

## Phase 5 — Storage + Realtime Database

### Completed
- Buckets/objects browse; download+share; upload (≤10 MB simple); rename copy+delete; delete
- RTDB instance discovery; hierarchical browse; JSON edit with ETag; create/delete child

### Limitations
- Resumable upload for large files not implemented (hard limit messaging)
- Download loads object into memory then temp file (size caution)

---

## Phase 6 — RC, Hosting, Distribution, Extensions, App Check, Rules

### Completed
- Remote Config get/publish (ETag)/versions/rollback (gated)
- Hosting sites list
- App Distribution apps/releases/groups (list)
- Extensions instances list
- App Check service enforcement list (apps browse API honestly unavailable)
- Rules: rulesets/releases **view** — publish intentionally not exposed without full validation workflow

### Limitations
- Billing module remains unavailable (no incomplete mutation UI)
- No mobile source deploy for Hosting

---

## Phase 7 — IAM, FCM, Cost Guard

### Completed
- IAM policy read-only
- FCM HTTP v1 test message with payload preview
- Cost Guard: session Firestore op counters + honest billing API note

### Limitations
- No IAM mutation in v1.0
- No live Cloud Billing budgets without owner BigQuery/Billing setup

---

## Phase 8 — Command Center

### Completed
- Account/project context, Safe Mode chip, environment badge
- Incident Center / Cost Guard / Monitoring links
- Favorites + recently viewed (local)
- iPad NavigationSplitView; iPhone tabs
- `firetap://` deep links

---

## Phase 9 — Safety / Privacy

### Completed
- Safe Mode default for production; Face ID write unlock; inactivity relock
- Optional app lock + inactivity + background lock
- Privacy blur when inactive (screenshot practical protection)
- Encrypted audit trail; typed confirmations; WriteGate
- In-app Privacy / Terms / Acknowledgments / Support + Google disclaimer
- PrivacyInfo.xcprivacy; no FireTap-owned account (explained in Settings)

---

## Phase 10 — StoreKit

### Completed
- Product `com.truesolutions.firetap.lifetime`; localized price from StoreKit
- Purchase, restore, Transaction.updates, pending/failed/revoked messaging
- `StoreKitConfig/FireTap.storekit` for local testing
- Free: one project read-only; Pro: multi-project + writes/admin modules

---

## Phase 11 — A11y / Localization / Performance

### Completed
- VoiceOver labels on key controls; Dynamic Type via Theme fonts
- Reduce Motion / privacy blur path
- Pagination, request cancellation patterns, MainActor networking boundaries
- English copy polished; localization architecture = String catalogs ready later (no broken machine translations shipped)

### Remaining (non-blocking)
- Full VoiceOver pass on every screen during device QA
- Instruments profiling on large datasets with live projects

---

## Phase 12 — Testing

### Results
- **113 unit tests, 0 failures**
- **2 UI tests, 0 failures** (launch + branding/config copy)
- Clean build succeeds with no FireTap source warnings

---

## Phase 13 — Final product audit

### Grep results (production)
- No Restroom Report / EmberPanel / ProjectControl product names in app code
- No hardcoded StoreKit prices in UI
- No committed secrets (`Secrets.xcconfig` git-ignored)
- No `print` / `NSLog` in production Swift
- `preconditionFailure` only in `URL(static:)` for invalid compile-time literals
- “placeholder” mentions are honest empty-body / cost-preview UI naming, not fake data
- Billing module explicitly unavailable; Rules publish not offered incomplete

---

## Phase 14 — Release preparation

### Completed docs
- `APP_STORE_METADATA.md`, checklists, OAuth/App Review notes, MANUAL_SETUP
- App icon 1024 present in asset catalog
- Version locked at 1.0 (1)

### External still required
- Real OAuth client + device QA
- Hosted Privacy/Terms/Support URLs
- ASC app + StoreKit product
- Signing team + Archive (then build may increment)

---

## Files changed (this multi-phase run)

See git status — Auth GSI migration, all Services/*, Feature browsers, audits under `docs/`, tests under `Tests/FireTapTests/`.
