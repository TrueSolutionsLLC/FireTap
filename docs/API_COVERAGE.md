# API Coverage Matrix

Every module maps to a documented, supported Google/Firebase REST API. The app **does not** scrape the Firebase Console or use private endpoints.

Legend — **Status**: ✅ live in app · 🟡 service client / model present, UI honest-state · ⬜ planned, honest-state only.

| Module | API(s) | Endpoints used | Status |
|---|---|---|---|
| Projects | Firebase Management API | `projects.list`, `projects.get`, `projects:searchApps` | ✅ |
| Command Center | Firebase Management + Cloud Monitoring | project facts live; metrics via Monitoring | 🟡 |
| Firestore (browse/read) | Cloud Firestore REST | `:listCollectionIds`, `documents.list` (paged), `documents.get` | ✅ |
| Firestore (write) | Cloud Firestore REST | `documents.patch` (w/ `updateMask` + `currentDocument.updateTime`), `documents.delete`, `documents.batchWrite` | ⬜ (guarded framework in place) |
| Authentication | Identity Toolkit / Identity Platform Admin | `accounts:batchGet` (paginated list), `accounts:lookup` (search by email/phone/UID), `accounts:query` (total count) live read; `accounts:update`/`:delete` planned (guarded writes) | 🟡 |
| Cloud Functions | Cloud Functions API v1/v2 | `functions.list`, `functions.get` | ⬜ |
| Logs | Cloud Logging API | `entries:list`, `entries:tail` | ⬜ |
| Cloud Storage | Cloud Storage JSON API | `buckets.list`, `objects.list` (delimiter-based folder browsing, cursor pagination), object metadata detail live read; download/preview/write planned | 🟡 |
| Realtime Database | RTDB REST + Management | `<db>.json` reads/writes, instances list | ⬜ |
| Remote Config | Remote Config REST | `getRemoteConfig`, `updateRemoteConfig` (ETag) | ⬜ |
| App Check | App Check API | apps/providers, enforcement | ⬜ |
| Security Rules | Firebase Rules API | `rulesets`, `releases`, `test` | ⬜ |
| Hosting | Firebase Hosting API | sites, channels, releases | ⬜ |
| App Distribution | App Distribution API | releases, groups, testers | ⬜ |
| IAM | Cloud Resource Manager + IAM | `getIamPolicy`, roles | ⬜ |
| Extensions | Firebase Extensions API | instances list | ⬜ |
| FCM | FCM HTTP v1 | `messages:send` (validate + preview) | ⬜ |
| Billing / Cost Guard | Cloud Billing + Monitoring | budgets, quota/usage series | 🟡 (session read counting live) |

## Preconditions & concurrency safety

- **Firestore writes** must send `currentDocument.updateTime` to prevent overwriting concurrent edits.
- **Remote Config** must send the `ETag` (`If-Match`) on publish.
- The `HTTPClient`/`GoogleAPIClient` expose `ETag` and map `409/412` to `APIError.preconditionFailed`.

## Notes on claims

The app never claims an operation works until it has been tested against a real non-production project. Modules marked ⬜/🟡 present honest configuration/permission/empty/error states rather than simulated results.
