# RELEASE_AUDIT

## Current readiness statement

**BLOCKED — with exact unresolved requirements**

### Unresolved before READY FOR DEVICE QA
1. Real Google OAuth **iOS Client ID** in `Config/Secrets.xcconfig` (create in Console — no public API). Project `firetap-truesolutions` + iOS app + APIs already provisioned.
2. ~~Firebase / core APIs on OAuth project~~ ✅ Enabled on `firetap-truesolutions`
3. ~~Apple Developer signing Team selected in Xcode~~ ✅ Team `2P268A8J66` set (also in `project.yml`)
4. Manual smoke: sign-in, token restore, project list, one module read path

### Unresolved before READY FOR TESTFLIGHT
- All of the above
- Hosted Privacy / Terms / Support URLs set in `Config/Shared.xcconfig`
- App Store Connect app record + non-consumable `com.truesolutions.firetap.lifetime`
- Archive + upload (build number may increment **only** when an Archive is created)

### Satisfied in repo (code gate)
- Clean build succeeds (warnings addressed)
- **123 unit + 2 UI tests** pass
- Version **1.0 (1)**
- No production mock data / no committed secrets
- Modules either live against public APIs or honestly unavailable
- StoreKit local config present; production uses App Store transactions
- Security audit: no open critical/high
- Privacy manifest present and aligned
- Release documentation present (`MANUAL_SETUP`, App Store metadata, checklists)
- Incremental write scopes wired into `WriteGate`
- Hosting channels/releases, Functions safe invoke, resumable Storage upload present

## Version
1.0 (1) — do not increment until a real Archive for TestFlight/ASC.

## Do not claim
- “Ready to ship”
- “Ready for TestFlight”
- “100% complete”

until the matching definition is actually satisfied.

## Next owner action
Follow `docs/MANUAL_SETUP.md` §1–2, then re-run live Phase 1 verification and update this file to **READY FOR DEVICE QA**.
