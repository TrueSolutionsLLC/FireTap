# MANUAL_SETUP

Owner-only steps. Some can be automated; OAuth **iOS Client ID creation** still requires Google Cloud Console (no public create API).

## Already done for you (2026-07-17)

| Step | Status |
|------|--------|
| Apple Developer Team in Xcode / `project.yml` | ✅ `2P268A8J66` |
| Display name + Developer Tools category | ✅ |
| Firebase/GCP project for FireTap app identity | ✅ `firetap-truesolutions` (project number `602381553296`) |
| iOS app registered (bundle `com.truesolutions.firetap`) | ✅ App ID `1:602381553296:ios:f0a0957cefd965fe53d215` |
| Core Google APIs enabled on that project | ✅ Firebase, Identity Toolkit, Firestore, Storage, Functions, Logging, Monitoring, Hosting, Rules, App Check, FCM, etc. |

## 1. Create iOS OAuth client (you — ~1 minute)

Google does **not** expose a public API to create classic “OAuth 2.0 Client ID” credentials. Do this once:

1. Open [OAuth consent screen](https://console.cloud.google.com/apis/credentials/consent?project=firetap-truesolutions) → External → app name **FireTap** → support email your Google account → Save.
2. Open [Create OAuth client](https://console.cloud.google.com/apis/credentials/oauthclient?project=firetap-truesolutions):
   - Application type: **iOS**
   - Name: **FireTap**
   - Bundle ID: **`com.truesolutions.firetap`**
3. Copy the **Client ID**.

Then apply secrets locally (git-ignored):

```bash
cd /Users/robbiej/Projects/FireTap
chmod +x scripts/apply-oauth-secrets.sh
./scripts/apply-oauth-secrets.sh "YOUR_CLIENT_ID.apps.googleusercontent.com"
```

The script derives the reversed URL scheme and regenerates the Xcode project.

Optional: click **Get started** on [Firebase Authentication](https://console.firebase.google.com/project/firetap-truesolutions/authentication) for that project.

### Live verification checklist (after Secrets filled)
- [ ] Welcome shows Sign in (not “not configured”)
- [ ] Google Sign-In completes
- [ ] Force-quit and relaunch restores session
- [ ] Projects list loads real projects
- [ ] Open a project → Command Center shows project facts
- [ ] Sign out / switch account behaves as expected

## 2. Apple Developer

✅ Team selected. Run on a physical device (Face ID / app lock) and simulator after OAuth secrets are applied.

## 3. StoreKit

**Local:** Scheme already uses `StoreKitConfig/FireTap.storekit`.

**App Store Connect (before TestFlight monetization QA):**
1. Create non-consumable product id: `com.truesolutions.firetap.lifetime`
2. Name: FireTap Lifetime

## 4. Legal URLs (before ASC submit)

Host Privacy Policy, Terms, and Support pages; set URLs in `Config/Shared.xcconfig`. Until then, in-app `LegalDocumentView` content is available.

## 5. Google verification (public release)

Submit OAuth consent for verification if external users + sensitive/restricted scopes.

## 6. Release Archive

Only when creating a real TestFlight/ASC Archive may you increment `CURRENT_PROJECT_VERSION`. Keep **1.0 (1)** for local development.
