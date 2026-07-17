# App Privacy Guidance (App Store Connect "Privacy Nutrition Label")

This maps the App's behavior to App Store Connect's Data Collection questionnaire and to the bundled `PrivacyInfo.xcprivacy`.

## Summary answer

**"Data Not Collected."** The developer does not collect data from this app in the App Store Connect sense: no personal data or usage data is transmitted to or stored on developer-controlled servers. All account and project data is exchanged directly between the user's device and Google.

If, during App Review, you are asked to justify this: the app has no backend; the only network destinations are Google/Firebase API domains, used with the user's own OAuth authorization.

## Per-category answers

| Data type | Collected? | Notes |
|---|---|---|
| Contact info (email/name) | No (not by developer) | Read from the user's Google profile on-device to display the connected account; never sent to us. |
| User content | No | Firestore/Storage/etc. data stays between device and Google. |
| Identifiers | No | No advertising identifier; no user id sent to us. |
| Usage data | No | No analytics SDK. |
| Diagnostics | No | No third-party crash/telemetry SDK. |
| Purchases | Handled by Apple | StoreKit; we don't receive personal purchase data. |

## Tracking

`NSPrivacyTracking = false`; no tracking domains; no ATT prompt needed.

## Required-reason APIs (`PrivacyInfo.xcprivacy`)

| API category | Reason code | Use |
|---|---|---|
| UserDefaults | `CA92.1` | Store the app's own preferences (pins, labels, last project). |
| File timestamp | `C617.1` | Manage the local encrypted audit log file. |

Keep this in sync if you add SDKs or new required-reason API usage.
