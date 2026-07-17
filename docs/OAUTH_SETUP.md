# Google OAuth Setup & Verification Checklist

FireTap signs in with **Google OAuth 2.0 Authorization Code Flow + PKCE** using an **iOS OAuth client**. iOS clients are *public clients*: there is **no client secret**, which is why nothing secret is ever compiled into the app.

## 1. Create the OAuth client

1. Open the [Google Cloud Console](https://console.cloud.google.com/) and select (or create) a project. For development, prefer a **dedicated non-production project**.
2. **APIs & Services → OAuth consent screen**
   - User type: External (or Internal for Workspace-only).
   - Fill in app name, support email, developer contact.
   - Add the scopes the app requests (see below). Some are **sensitive/restricted** and require verification before public release.
3. **APIs & Services → Credentials → Create Credentials → OAuth client ID**
   - Application type: **iOS**.
   - Bundle ID: must match `APP_BUNDLE_ID` in `Config/Shared.xcconfig` (default `com.truesolutions.firetap`).
4. Copy the **Client ID** (`…apps.googleusercontent.com`) and the **iOS URL scheme** (`com.googleusercontent.apps.…`).

## 2. Enable the APIs you plan to use

Enable, per project you connect (or once at the org level), the APIs backing the modules you use — e.g.:

- Firebase Management API
- Cloud Firestore API
- Cloud Functions API, Cloud Logging API, Cloud Monitoring API
- Identity Toolkit API
- Cloud Storage / Firebase Storage
- Firebase Realtime Database Management API
- Firebase Remote Config API, Firebase Rules API, Firebase App Check API
- Cloud Resource Manager API, IAM API
- Firebase Hosting API, Firebase App Distribution API, Firebase Extensions API
- Firebase Cloud Messaging API, Cloud Billing API

If an API isn't enabled, the corresponding screen shows an honest **permission / API-not-enabled** state (a `403`), never a fake success.

## 3. Fill in Secrets.xcconfig

```
cp Config/Secrets.xcconfig.example Config/Secrets.xcconfig
```

```ini
GOOGLE_OAUTH_CLIENT_ID = 1234567890-abcdef.apps.googleusercontent.com
GOOGLE_OAUTH_REDIRECT_SCHEME = com.googleusercontent.apps.1234567890-abcdef
```

`Secrets.xcconfig` is git-ignored. Regenerate the project (`xcodegen generate`) and run.

## 4. Scopes requested (minimum)

| Scope | Why | Sensitivity |
|---|---|---|
| `openid` | Sign-in | — |
| `.../auth/userinfo.email` | Show which account is connected | — |
| `.../auth/userinfo.profile` | Name / avatar in the account switcher | — |
| `.../auth/cloud-platform` | Read projects, metrics, logs, Firestore, users, storage; perform approved admin actions | **Sensitive/Restricted** |
| `.../auth/firebase.database` | Realtime Database module | Sensitive |

The app explains every scope **before** authorization (`ScopeConsentView`) and requests the minimum needed for the enabled modules.

> `cloud-platform` is broad because it is the documented scope that Firestore Admin, Cloud Logging, Monitoring, IAM, Storage, and Firebase Management accept. If you only need read access to a subset, you can tighten `AppConfig.oauthScopes` and `requiredScopeValues`.

## 5. Google verification checklist (before public App Store release)

- [ ] OAuth consent screen completed with accurate app name, logo, and domains.
- [ ] Authorized domain(s) verified in Search Console.
- [ ] Privacy Policy URL live and reachable (see `docs/PRIVACY_POLICY.md`).
- [ ] Terms of Use URL live (see `docs/TERMS_OF_USE.md`).
- [ ] Demo video showing the OAuth flow and how each sensitive scope is used.
- [ ] Justification for each sensitive/restricted scope (data stays on-device, not sent to any app server).
- [ ] App name and branding do not imply Google endorsement.
- [ ] Restricted-scope security assessment completed if required for your user base.
- [ ] Contact email monitored for Google's review correspondence.
- [ ] Confirm the app does **not** store or transmit user data to app-owned servers (a common approval blocker) — FireTap does not.

## Troubleshooting

- **`redirect_uri_mismatch`** — the reversed-client-id scheme in `Secrets.xcconfig` must exactly match the iOS URL scheme from the console, and the bundle id must match.
- **`invalid_grant` on refresh** — the refresh token was revoked/expired; the app surfaces a reauthentication state.
- **No refresh token returned** — ensure the flow uses `access_type=offline` and `prompt=consent` (it does); revoke prior grants if Google stops returning a refresh token.
