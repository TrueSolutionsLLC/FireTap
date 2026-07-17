import SwiftUI

/// The service directory shown under the Data tab. Each entry maps to a
/// Firebase / Google Cloud module backed by a documented public REST API.
enum ServiceModule: String, CaseIterable, Identifiable {
    case firestore
    case authentication
    case functions
    case logs
    case storage
    case realtimeDatabase
    case remoteConfig
    case appCheck
    case hosting
    case appDistribution
    case iam
    case extensions
    case rules
    case fcm
    case billing

    var id: String { rawValue }

    var title: String {
        switch self {
        case .firestore: return "Firestore"
        case .authentication: return "Authentication"
        case .functions: return "Cloud Functions"
        case .logs: return "Logs"
        case .storage: return "Cloud Storage"
        case .realtimeDatabase: return "Realtime Database"
        case .remoteConfig: return "Remote Config"
        case .appCheck: return "App Check"
        case .hosting: return "Hosting"
        case .appDistribution: return "App Distribution"
        case .iam: return "IAM"
        case .extensions: return "Extensions"
        case .rules: return "Security Rules"
        case .fcm: return "Cloud Messaging"
        case .billing: return "Billing & Usage"
        }
    }

    var symbol: String {
        switch self {
        case .firestore: return "tablecells"
        case .authentication: return "person.2.fill"
        case .functions: return "bolt.fill"
        case .logs: return "text.alignleft"
        case .storage: return "externaldrive.fill"
        case .realtimeDatabase: return "point.3.connected.trianglepath.dotted"
        case .remoteConfig: return "slider.horizontal.3"
        case .appCheck: return "checkmark.shield.fill"
        case .hosting: return "globe"
        case .appDistribution: return "paperplane.fill"
        case .iam: return "key.fill"
        case .extensions: return "puzzlepiece.extension.fill"
        case .rules: return "doc.text.magnifyingglass"
        case .fcm: return "bell.badge.fill"
        case .billing: return "creditcard.fill"
        }
    }

    var tint: Color {
        switch self {
        case .firestore, .rules: return Theme.Palette.accent
        case .authentication, .iam: return Theme.Palette.info
        case .functions, .fcm: return Theme.Palette.warning
        case .storage, .appCheck, .hosting: return Theme.Palette.healthy
        case .billing: return Theme.Palette.danger
        default: return Theme.Palette.textSecondary
        }
    }

    /// The public API this module uses (shown to set honest expectations).
    var backingAPI: String {
        switch self {
        case .firestore: return "Cloud Firestore REST API"
        case .authentication: return "Identity Toolkit / Identity Platform Admin API"
        case .functions: return "Cloud Functions API"
        case .logs: return "Cloud Logging API"
        case .storage: return "Cloud Storage JSON API"
        case .realtimeDatabase: return "Realtime Database REST API"
        case .remoteConfig: return "Firebase Remote Config REST API"
        case .appCheck: return "Firebase App Check API"
        case .hosting: return "Firebase Hosting API"
        case .appDistribution: return "Firebase App Distribution API"
        case .iam: return "Cloud IAM / Resource Manager API"
        case .extensions: return "Firebase Extensions API"
        case .rules: return "Firebase Rules API"
        case .fcm: return "Firebase Cloud Messaging API"
        case .billing: return "Cloud Billing / Monitoring API"
        }
    }
}
