# App Store Release Checklist

## Code quality
- [ ] `xcodebuild ... build` succeeds with **no warnings**.
- [ ] **No Swift concurrency warnings** (strict `complete`).
- [ ] **No force unwraps** in production code (search `!` usages in `FireTap/`).
- [ ] `xcodebuild ... test` passes.
- [ ] No mock/sample data anywhere in the app target (only in `Tests/`).

## Security & privacy
- [ ] No secrets committed (`Config/Secrets.xcconfig` git-ignored; verify `git ls-files`).
- [ ] Logs contain no tokens, headers, bodies, or emails (spot-check `RedactedLog` usage).
- [ ] `PrivacyInfo.xcprivacy` present and accurate; validated during archive.
- [ ] App Privacy answers in App Store Connect match `docs/APP_PRIVACY.md`.

## Product
- [ ] Product name, bundle id, StoreKit product id finalized in `Config/*.xcconfig`.
- [ ] StoreKit product created in App Store Connect matching `STOREKIT_PRO_PRODUCT_ID`, price tier ($24.99 target).
- [ ] Purchase + Restore verified (sandbox, then TestFlight).
- [ ] Free tier usable (read-only, one project); Pro unlocks multiple + writes.

## Functional (against a non-production project)
- [ ] OAuth sign-in, refresh, revoke, reauth.
- [ ] Every shipped screen shows live data or an honest state — never fake.
- [ ] Firestore reads paginated and counted; large-read warning shown.
- [ ] All destructive actions guarded (exact target, typed confirmation, audit entry).
- [ ] Permission failures are understandable.

## Accessibility & layout
- [ ] VoiceOver pass; Dynamic Type up to AX5; Reduce Motion.
- [ ] Light and dark verified.
- [ ] iPhone and iPad (split view) verified.

## Store assets
- [ ] Screenshots (iPhone 6.9", iPad 13") light + dark.
- [ ] Description, keywords, promo text, support & privacy URLs live.
- [ ] Age rating completed (expected 4+).
- [ ] App Review notes include Google test account / demo video.

## Submit
- [ ] Archive validated and uploaded.
- [ ] TestFlight beta completed (see `docs/TESTFLIGHT_CHECKLIST.md`).
- [ ] Critical & high-priority bugs resolved.
- [ ] Submit for App Review.
