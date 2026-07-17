# TestFlight Checklist

## Prerequisites
- [ ] Apple Developer Program membership active.
- [ ] App record created in App Store Connect with bundle id `com.truesolutions.firetap` (or your configured id).
- [ ] Signing set up (automatic or a distribution certificate + provisioning profile).
- [ ] `Config/Secrets.xcconfig` contains a **real** OAuth client id whose iOS client bundle id matches.
- [ ] Version 1.0, build 1 (bump build for each upload).

## Build & upload
- [ ] `xcodegen generate`
- [ ] Select a real device / "Any iOS Device" and set signing team in the target.
- [ ] Product → Archive (Release).
- [ ] Validate the archive (no missing entitlements, privacy manifest present).
- [ ] Distribute → App Store Connect → Upload.

## App Store Connect (TestFlight tab)
- [ ] Export compliance: uses standard encryption only (`ITSAppUsesNonExemptEncryption = false`).
- [ ] Add internal testers; add a build to a group.
- [ ] Provide "What to Test" notes.
- [ ] For external testers: submit for Beta App Review; include Google test-account credentials or a demo video (OAuth requires a live account).

## Smoke test on TestFlight build
- [ ] Fresh install launches to Welcome (or config state if OAuth not set).
- [ ] Sign in with a real Google account (system browser).
- [ ] Projects load; open one; Firestore collections + a document load.
- [ ] Production project opens read-only; Face ID unlock works and relocks on background.
- [ ] Purchase Pro (sandbox) and Restore Purchases.
- [ ] Disconnect + Delete Local Credentials behave correctly.
- [ ] Light/dark, iPhone + iPad.

## Known live-testing dependencies
- Real OAuth verification status affects the consent screen ("unverified app" warning until Google verification completes).
