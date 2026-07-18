# App Store Metadata Draft & Review Notes

## Listing

- **Name:** FireTap: Firebase Admin
- **Subtitle:** Firestore, Auth & Functions
- **Tagline / promo hook:** Fix Firebase from your phone.
- **Category:** Developer Tools (Primary), Utilities (Secondary)
- **Age rating:** 4+ (no objectionable content). See age-rating notes below.
- **Price:** Free (with a single non-consumable Pro unlock — **display price from StoreKit only**)

> **Independent-app disclaimer (keep in listing):** FireTap is an independent third-party Firebase administration client. It is not affiliated with, endorsed by, or sponsored by Google LLC. "Firebase" and "Google Cloud" are trademarks of Google LLC. FireTap does not use official Firebase branding or logos.

### Promotional text (≤170 chars)
Fix Firebase from your phone. Inspect Firestore, manage Auth users, monitor production, and act safely — your data never touches our servers.

### Description (draft)
FireTap is a native console for developers who manage Firebase and Google Cloud projects. Connect your Google account with the official Google Sign-In SDK (Authorization Code + PKCE — we never see your password), browse your real projects, inspect Firestore with paginated, cost-aware reads, review Authentication users and Cloud Storage, and keep production safe with read-only Safe Mode and Face ID-gated writes.

Privacy by architecture: your project data travels directly between your device and Google. Nothing is routed through our servers, and tokens stay in the Google Sign-In Keychain store on device.

Free includes read-only access to one connected project. FireTap Pro — a one-time purchase, no subscription — unlocks multiple projects and write/admin actions. All safety protections remain enabled after purchase.

FireTap is an independent third-party Firebase administration client. It is not affiliated with, endorsed by, or sponsored by Google LLC.

Features:
- Real Firebase project list with search, sort, pins, and environment labels
- Firestore browser with pagination, queries, and gated writes
- Authentication user admin with typed destructive confirmations
- Cloud Functions, Logging, Monitoring, Incident Center
- Storage and Realtime Database browse/edit with concurrency protections
- Remote Config, Hosting, App Distribution, Extensions, App Check, Rules (read)
- IAM read-only, FCM test send, session Cost Guard
- Production Safe Mode, optional app lock, encrypted local action history

### Keywords
firebase,firestore,google cloud,gcp,devops,console,admin,logs,functions,database,monitoring

### What's New (1.0)
Initial release.

### Support / Marketing URLs
- Support: placeholder — set `PCSupportURL` in xcconfig before submit
- Privacy Policy: placeholder — set `PCPrivacyPolicyURL`
- Terms: placeholder — set `PCTermsURL`

Do not fabricate live URLs in App Store Connect until pages are hosted.

## App Review notes

- **Sign-in:** Requires a Google account with access to at least one Firebase/GCP project. Provide a reviewer test Google account with a demo Firebase project, or a demo video.
- **OAuth:** Uses official **Google Sign-In for iOS** (Authorization Code + PKCE). Bundle ID `com.truesolutions.firetap`. Redirect scheme is Google’s reversed client ID. Explain that client ID is a public iOS client (no client secret).
- **No password handling:** FireTap never displays, requests, or stores end-user Firebase Auth passwords. Password reset triggers Google’s email action only.
- **No hidden features behind paywall:** Navigable free; Pro unlocks multiple projects and write/admin actions.
- **No mock data:** Live Google APIs or honest empty/error/unavailable states.
- **Data routing:** Device ↔ Google only; no app-owned backend for project data.
- **StoreKit:** Non-consumable `com.truesolutions.firetap.lifetime`. Localized price from StoreKit. Restore Purchases supported. Use StoreKit Testing / sandbox — do not hardcode a customer-facing price in review notes.
- **Account deletion:** FireTap does not create FireTap accounts. Settings → Disconnect revokes Google access and clears the local session.

## Export compliance
- Uses HTTPS / standard encryption only; typically qualifies for exemption — confirm current ASC questionnaire answers with counsel if needed.

## Age rating questionnaire notes
- No violence, sexual content, profanity, gambling, or public UGC.
- Unrestricted web access: **No** (Google/Firebase API domains + configured legal URLs).
- Expected rating: **4+**.

## Screenshots to capture (per device size)
1. Welcome / privacy promise
2. Projects list (with a production label)
3. Command Center (project facts + Safe Mode)
4. Firestore collections / document detail
5. Incident Center or Logs
6. Settings (account + Pro with StoreKit price)

Capture on iPhone 6.9" and iPad 13" in both light and dark.

## Google OAuth production-verification checklist
See `docs/OAUTH_SETUP.md` — required before broad external distribution with sensitive scopes.

## App Store Connect / TestFlight checklists
See `docs/RELEASE_CHECKLIST.md` and `docs/TESTFLIGHT_CHECKLIST.md`.
