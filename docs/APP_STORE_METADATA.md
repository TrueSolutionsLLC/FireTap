# App Store Metadata Draft & Review Notes

## Listing

- **Name:** FireTap: Firebase Admin
- **Subtitle:** Firestore, Auth & Functions
- **Tagline / promo hook:** Fix Firebase from your phone.
- **Category:** Developer Tools (Primary), Utilities (Secondary)
- **Age rating:** 4+ (no objectionable content). See age-rating notes below.
- **Price:** Free (with a single non-consumable Pro unlock)

> **Independent-app disclaimer (keep in listing):** FireTap is an independent, third-party tool and is not affiliated with, endorsed by, or sponsored by Google or Apple. "Firebase" and "Google Cloud" are trademarks of Google LLC. FireTap does not use official Firebase branding or logos.

### Promotional text (≤170 chars)
Fix Firebase from your phone. Inspect Firestore, manage Auth users, monitor production, and act safely — your data never touches our servers.

### Description (draft)
FireTap is a native console for developers who manage Firebase and Google Cloud projects. Connect your Google account securely (OAuth with PKCE — we never see your password), browse your real projects, inspect Firestore with paginated, cost-aware reads, review Authentication users and Cloud Storage, and keep production safe with read-only Safe Mode and Face ID-gated writes.

Privacy by architecture: your project data travels directly between your device and Google. Nothing is routed through our servers, and refresh tokens stay in your device's Keychain.

Free includes read-only access to one connected project. FireTap Pro — a one-time purchase, no subscription — unlocks multiple projects and write/admin actions.

FireTap is an independent tool and is not affiliated with Google or Apple.

Features:
- Real Firebase project list with search, sort, pins, and environment labels
- Firestore browser with pagination and per-session read counting
- Production Safe Mode with Face ID unlock and automatic relock
- Honest states everywhere — no fake data, ever

### Keywords
firebase,firestore,google cloud,gcp,devops,console,admin,logs,functions,database,monitoring

### What's New (1.0)
Initial release.

### Support / Marketing URLs
- Support: `SUPPORT_URL`
- Privacy Policy: `PRIVACY_POLICY_URL`

## App Review notes

- **Sign-in:** Requires a Google account with access to at least one Firebase/GCP project. Please use a reviewer test Google account with a demo Firebase project. (Provide credentials in the "App Review Information" → notes, or a demo video.)
- **No password handling:** Authentication uses `ASWebAuthenticationSession` (system browser) with OAuth 2.0 + PKCE.
- **No hidden features behind paywall:** The app is fully navigable free; Pro only unlocks multiple projects and write/admin actions.
- **No mock data:** Every screen shows live data or an honest configuration/permission/empty/error state.
- **Data routing:** All project data goes directly device↔Google; there is no app-owned backend.
- **StoreKit:** One non-consumable, `com.truesolutions.firetap.lifetime`, $24.99. Restore Purchases supported.
- **Account deletion:** Settings → Disconnect revokes the Google grant and removes local credentials.

## Age rating questionnaire notes
- No violence, sexual content, profanity, gambling, or user-generated content shared publicly.
- Unrestricted web access: **No** (only Google/Firebase API domains + your configured legal URLs).
- Expected rating: **4+**.

## Screenshots to capture (per device size)
1. Welcome / privacy promise
2. Projects list (with a production label)
3. Command Center (project facts)
4. Firestore collections
5. Firestore document detail (fields + JSON)
6. Settings (account + Pro)

Capture on iPhone 6.9" and iPad 13" in both light and dark.
