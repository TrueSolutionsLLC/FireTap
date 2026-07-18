# PRIVACY_AUDIT

**Date:** 2026-07-17  
**Version:** 1.0 (1)

## Data flow

- Google identity + Firebase/GCP project data: **device ↔ Google APIs only**
- No FireTap analytics SDK
- No FireTap-owned server for customer project data
- Local: Keychain (Google Sign-In), UserDefaults preferences, encrypted audit trail

## PrivacyInfo.xcprivacy

- Tracking: **false**
- Collected data types: **none declared** (matches no analytics)
- Required Reason APIs: UserDefaults (CA92.1), File timestamp (C617.1 for audit log)

## Account deletion

FireTap does **not** create a FireTap account. Disconnect / delete local credentials removes the Google Sign-In session (and Disconnect revokes the grant). Explained in Settings.

## Legal

- In-app Privacy Policy, Terms, Acknowledgments, Support text
- Required disclaimer present: independent third-party; not affiliated with Google LLC
- Hosted URL placeholders in xcconfig — **must be filled before ASC submit**

## Screenshots / sensitive UI

- Privacy blur when inactive if enabled
- Passwords never requested or displayed for Auth users
- Redacted logging categories for auth/store

## Status

Privacy manifest matches declared behavior. Hosted policy URLs remain an **external** release dependency.
