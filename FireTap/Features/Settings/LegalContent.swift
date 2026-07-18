import Foundation

enum LegalDocument: String, CaseIterable, Identifiable {
    case privacyPolicy
    case termsOfUse
    case acknowledgments
    case support

    var id: String { rawValue }

    var title: String {
        switch self {
        case .privacyPolicy: return "Privacy Policy"
        case .termsOfUse: return "Terms of Use"
        case .acknowledgments: return "Acknowledgments"
        case .support: return "Support & Disclaimer"
        }
    }

    var markdown: String {
        switch self {
        case .privacyPolicy: return Self.privacyPolicyText
        case .termsOfUse: return Self.termsOfUseText
        case .acknowledgments: return Self.acknowledgmentsText
        case .support: return Self.supportText
        }
    }

    private static let disclaimer = """
    **FireTap is an independent third-party Firebase administration client. It is not affiliated with, endorsed by, or sponsored by Google LLC.**
    """

    private static let privacyPolicyText = """
    # Privacy Policy

    \(disclaimer)

    FireTap connects directly from your device to Google and Firebase APIs using your Google account. We do not operate a FireTap account service — your identity comes from Google Sign-In.

    ## What stays on your device
    - Google Sign-In session tokens managed by the Google Sign-In SDK
    - Project pins, environment labels, favorites, and recently viewed resources
    - Optional encrypted audit entries for actions you perform in FireTap
    - App Lock and privacy preferences

    ## What we do not collect
    FireTap does not send your Firebase data through a FireTap-operated backend. API traffic goes device ↔ Google.

    ## Your choices
    You can disconnect Google access, delete local credentials, or remove the app at any time from Settings.

    For questions, use the Support link in Settings.
    """

    private static let termsOfUseText = """
    # Terms of Use

    \(disclaimer)

    By using FireTap you agree to use it responsibly on Firebase projects you are authorized to access.

    ## No warranty
    FireTap is provided as-is. Always verify destructive changes in production projects.

    ## Google terms
    Your use of Google and Firebase services remains subject to Google's terms and policies.

    ## Pro purchase
    FireTap Pro is a one-time, non-consumable in-app purchase processed by Apple. Entitlements are tied to your Apple ID.
    """

    private static let acknowledgmentsText = """
    # Acknowledgments

    \(disclaimer)

    FireTap uses Apple's SwiftUI framework, the Google Sign-In SDK, and documented Google / Firebase REST APIs.

    Firebase, Google Cloud, and related marks are trademarks of Google LLC.
    """

    private static let supportText = """
    # Support & Disclaimer

    \(disclaimer)

    ## Getting help
    Use the external Support URL in Settings for release-specific assistance.

    ## Account deletion
    FireTap does not create FireTap accounts. Signing in uses Google. Removing the app or deleting local credentials does not delete your Google account.

    ## Safe Mode
    Production projects open read-only until you explicitly unlock write access with biometrics.
    """
}
