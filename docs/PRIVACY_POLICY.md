# Privacy Policy (Template)

_Last updated: {{DATE}}. Replace {{PLACEHOLDERS}} and have counsel review before publishing._

**{{COMPANY_NAME}}** ("we", "us") publishes **FireTap** (the "App"). This policy explains how the App handles information.

## The short version

- We do **not** run a server that receives your Firebase/Google Cloud project data. Your data goes **directly** between your device and Google's APIs.
- We do **not** sell data, show ads, or use third-party analytics/tracking SDKs.
- Your Google **refresh token** is stored only in your device's **Keychain**.

## Information the App accesses

- **Google account identity** (name, email, avatar) — shown so you know which account is connected. Retrieved from Google on sign-in; not transmitted to us.
- **Your Firebase / Google Cloud project data** — read (and, where you explicitly act, modified) directly via Google APIs, on your device, under the OAuth scopes you approve. Never routed through or stored by us.
- **On-device app preferences** — pinned projects, environment labels, last-opened project (stored in `UserDefaults`).
- **Local audit trail** — a record of administrative actions you take, stored **encrypted** on your device only.

## What we collect on our servers

Nothing. The App has no backend that receives your account or project data.

## Authentication

Sign-in uses Google OAuth 2.0 with PKCE in the system browser. The App never sees or stores your Google password and never imports service-account keys.

## Data sharing

We do not share your data because we do not receive it. Data is exchanged only between your device and Google under your authorization. See Google's Privacy Policy for how Google processes it.

## Data retention & deletion

- Tokens remain in the Keychain until you use **Disconnect** (which also revokes the grant with Google) or **Delete Local Credentials**.
- Uninstalling the App removes local preferences and the encrypted audit trail.

## Children

The App is for developers/administrators and is not directed to children under 13.

## Changes

We may update this policy; the "Last updated" date will change.

## Contact

{{SUPPORT_EMAIL}} · {{COMPANY_ADDRESS}}
