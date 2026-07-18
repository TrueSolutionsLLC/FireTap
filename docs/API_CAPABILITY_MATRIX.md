# API Capability Matrix

Documents which public Google/Firebase APIs FireTap uses and what the UI claims.

| Module | API | Operations | Status | Honest limitation |
|--------|-----|------------|--------|-------------------|
| Projects | Firebase Management v1beta1 | `projects.list`, `projects.get`, apps list | ✅ Live read | Requires Firebase Management API + OAuth |
| Firestore | Firestore REST v1 | databases, collections, documents, runQuery, create, patch, delete | ✅ Live | Writes: Pro + Safe Mode + write scopes; query ops + orderBy; page sizes ≠ billed reads |
| Authentication | Identity Toolkit Admin | batchGet, lookup, update, delete, sendOobCode | ✅ Live | No passwords; write scopes via WriteGate incremental auth |
| Cloud Functions | Cloud Functions v1/v2 | list + manual HTTPS invoke | ✅ Live | Invoke only for API-known URL; no auto-execute; no deploy |
| Logging | Cloud Logging v2 | entries.list | ✅ Live | Grouping is client-side |
| Monitoring | Cloud Monitoring v3 | timeSeries.list | ✅ Live | May be empty/delayed; never invent series |
| Storage | Storage JSON API | buckets, objects, upload (simple+resumable), download, copy, delete | ✅ Live | Resumable ≤100 MB in-memory; rename = copy+delete |
| Realtime DB | RTDB REST | instances, get/put/delete + ETag | ✅ Live | Large-read warning; JSON editor |
| Remote Config | Firebase RC REST | get, publish (If-Match), versions, rollback | ✅ Live | ETag conflicts surfaced |
| Hosting | Firebase Hosting API | sites, channels, releases | ✅ Live read | No phone source deploy |
| App Distribution | App Distribution API | apps, releases, groups | ✅ Live read | Actions only if API + perms allow |
| Extensions | Extensions API | list instances | ✅ Live read | Links/ops only when supported |
| App Check | App Check API | services list / get | ✅ Partial | No public project-wide apps browse for providers |
| Rules | Firebase Rules API | rulesets, releases (read) | ✅ Read | Publish not exposed without full safe workflow |
| IAM | Cloud Resource Manager | getIamPolicy | ✅ Read-only | No mutation in v1.0 |
| FCM | FCM HTTP v1 | messages.send (manual test) | ✅ Live | Single token; preview required; no auto-send |
| Billing / Quotas | — | — | ❌ Unavailable | Cost Guard uses **session** counters only; no fake budgets |

Legend: ✅ live · 🟡 partial · ❌ unavailable (honest UI)
