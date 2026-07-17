# Support (Template)

_Replace {{PLACEHOLDERS}} and host this content at your Support URL (`SUPPORT_URL` in `Config/Shared.xcconfig`)._

## Getting help

- **Email:** {{SUPPORT_EMAIL}}
- **Response time:** typically within {{RESPONSE_TIME}} business days.

## Common questions

**Does my project data go through your servers?**
No. FireTap talks directly to Google APIs from your device. We never receive your project data.

**Where are my credentials stored?**
Your Google refresh token is stored only in the iOS Keychain on your device. Use **Settings → Disconnect** to revoke access with Google, or **Delete Local Credentials** to remove tokens locally.

**Why does a screen say "not permitted" or "API not enabled"?**
Your Google account lacks permission for that resource, or the backing API isn't enabled on the project. Enable it in the Google Cloud Console (see the module's named API).

**Why am I asked for Face ID?**
Production projects open read-only. Unlocking write access requires biometric authentication, which relocks automatically when you leave the app or after inactivity.

**Will viewing data cost money?**
It can. Firestore reads (and other operations) may be billable. The app counts reads per session and warns before large reads. Google budget alerts are not hard caps.

**How do I restore Pro?**
Settings → Restore Purchases (uses your Apple ID).

## Reporting security issues

Please email {{SECURITY_EMAIL}} privately rather than filing a public report.
