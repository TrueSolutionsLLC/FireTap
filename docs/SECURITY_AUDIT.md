# SECURITY_AUDIT

**Date:** 2026-07-17  
**Version:** 1.0 (1)  
**Overall:** No unresolved **critical** or **high** findings in code. External OAuth/signing still required for live verification.

## Critical / High

| Finding | Severity | Status |
|---------|----------|--------|
| None open in repository | — | — |

## Medium / Low (accepted or mitigated)

| Finding | Severity | Mitigation |
|---------|----------|------------|
| OAuth client not configured in local Secrets | Medium (env) | Honest “not configured” UI; blocked for live QA |
| Write scopes broader (`cloud-platform`) when requested | Medium | Incremental auth only at write time; Safe Mode + typed confirm |
| Storage download loads object into memory | Low | Size caution; large-file resumable upload deferred |
| Rules publish not implemented | Info | Intentionally omitted incomplete mutation surface |
| IAM mutation not implemented | Info | Read-only by design for v1.0 |

## Controls verified in code

- No FireTap-owned backend for credentials or project data
- No service-account JSON usage
- Google Sign-In SDK Keychain for tokens; no token logging (`RedactedLog`)
- `Secrets.xcconfig` git-ignored
- Safe Mode + Face ID for production writes
- Optional app lock + inactivity + background relock
- Typed confirmation for destructive actions
- ETag / updateTime preconditions on supported writes
- Privacy blur when scene inactive (practical screenshot protection)
- ATS default (no arbitrary loads declared)
- Minimal entitlements; no private APIs found in audit grep

## Residual risk

Live permission/revocation behavior must be confirmed on a real Google account after OAuth setup.
