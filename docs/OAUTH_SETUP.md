# Google Sign-In & OAuth Setup (Phase 1)

FireTap signs in with the **official Google Sign-In SDK for iOS**. The SDK performs **OAuth 2.0 Authorization Code Flow with PKCE**. There is **no client secret** in the app. Access and refresh tokens stay in the SDK’s **Keychain-backed** storage — never UserDefaults, logs, or an app-owned server.

## 1. Create the OAuth iOS client

1. Open [Google Cloud Console](https://console.cloud.google.com/) → select (or create) the GCP project that will own the OAuth client.
2. **APIs & Services → OAuth consent screen**
   - User type: **External** (unless you only use Google Workspace internal users).
   - App name: **FireTap**
   - Support email: your email
   - Developer contact: your email
   - Save.
3. **APIs & Services → Credentials → Create credentials → OAuth client ID**
   - Application type: **iOS**
   - Name: `FireTap iOS`
   - Bundle ID: **`com.truesolutions.firetap`** (must match `APP_BUNDLE_ID` in `Config/Shared.xcconfig`)
4. Copy:
   - **Client ID** (ends with `.apps.googleusercontent.com`)
   - **iOS URL scheme** (reversed client id, starts with `com.googleusercontent.apps.`)

## 2. Enable APIs used in Phase 1

In the same GCP project (or each Firebase project’s parent, depending on how you organize IAM):

| API | Why |
|-----|-----|
| **Firebase Management API** | List / get Firebase projects |
| **Identity Toolkit API** (optional later) | Auth user admin (not Phase 1) |

For Phase 1 project listing, enable **Firebase Management API**:
**APIs & Services → Library → “Firebase Management API” → Enable**.

## 3. Configure FireTap locally

```bash
cp Config/Secrets.xcconfig.example Config/Secrets.xcconfig
```

Edit `Config/Secrets.xcconfig` (git-ignored):

```ini
GOOGLE_OAUTH_CLIENT_ID = 1234567890-abcdef.apps.googleusercontent.com
GOOGLE_OAUTH_REDIRECT_SCHEME = com.googleusercontent.apps.1234567890-abcdef
```

- `GOOGLE_OAUTH_CLIENT_ID` = the iOS client id from step 1.
- `GOOGLE_OAUTH_REDIRECT_SCHEME` = the **exact** “iOS URL scheme” Google shows (reversed client id).  
  Do **not** invent a custom scheme like `com.truesolutions.firetap.oauth` for Google Sign-In — the SDK expects the reversed client id.

Then:

```bash
xcodegen generate
open FireTap.xcodeproj
```

Select your development Team under Signing & Capabilities, plug in a device or simulator, and Run.

## 4. Scopes FireTap requests (Phase 1)

Shown in-app before sign-in (`ScopeConsentView`):

| Scope | Purpose |
|-------|---------|
| `openid` | Secure sign-in |
| `userinfo.email` | Show which Google account is connected |
| `userinfo.profile` | Name / avatar in the account switcher |
| `https://www.googleapis.com/auth/firebase.readonly` | List real Firebase projects (read-only) |

Write / admin scopes (`cloud-platform`, etc.) are **not** requested at first sign-in. They will be requested later via **incremental authorization** when the user attempts a write action.

## 5. What you should see when it works

1. Welcome → Continue with Google → consent sheet → Google account picker.
2. Project list loads **real** Firebase projects for that account (name, ID, number, lifecycle).
3. Kill and reopen the app → session restores without signing in again.
4. Account switcher → “Use a different Google account” works.
5. Sign out / Delete Local Credentials → next launch shows Welcome.

## 6. Google verification (required before public release)

Until the OAuth app is verified, Google shows an **“unverified app”** warning and may limit which users can sign in.

Checklist for production release:

- [ ] OAuth consent screen complete (app name, logo optional but recommended, homepage, privacy policy, terms URLs).
- [ ] Scopes justified in the consent screen (especially any sensitive/restricted scopes added later for writes).
- [ ] Privacy Policy + Terms hosted at the URLs in `Config/Shared.xcconfig`.
- [ ] Submit for [Google OAuth verification](https://support.google.com/cloud/answer/9110914) if you use sensitive or restricted scopes with external users.
- [ ] `firebase.readonly` is generally sufficient for Phase 1; adding `cloud-platform` later may trigger additional verification.
- [ ] Confirm FireTap does **not** send user tokens or Firebase data to any FireTap-owned server (it does not).

## 7. Troubleshooting

| Symptom | Fix |
|---------|-----|
| “Sign-in not configured” | `Secrets.xcconfig` missing/empty, or client id doesn’t end with `.apps.googleusercontent.com`. Rebuild after editing. |
| Redirect / URL scheme errors | Scheme must be the reversed client id from Google; Info.plist `CFBundleURLTypes` + `GIDClientID` are filled from xcconfig. |
| Projects empty but account has Firebase apps | Enable Firebase Management API; ensure the Google account is Owner/Editor/Viewer on those Firebase projects. |
| 403 on project list | Missing `firebase.readonly` (or broader) scope, or IAM on the Firebase project. |
| Session doesn’t restore | User chose Sign out / Delete Local Credentials, or Keychain access group mismatch after changing bundle id. |

## 8. Security reminders

- Never commit `Config/Secrets.xcconfig`.
- Never add a Google **client secret** to the iOS app.
- Never log authorization headers, tokens, or emails (`RedactedLog` is used throughout).
- Customer Firebase data travels **device ↔ Google only**.
