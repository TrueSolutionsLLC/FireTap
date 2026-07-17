import SwiftUI

/// User-assignable environment label for a project. Drives the production
/// indicator and Safe Mode defaults.
enum ProjectEnvironment: String, Codable, Sendable, CaseIterable, Identifiable {
    case production
    case staging
    case development
    case test
    case unlabeled

    var id: String { rawValue }

    var title: String {
        switch self {
        case .production: return "Production"
        case .staging: return "Staging"
        case .development: return "Development"
        case .test: return "Test"
        case .unlabeled: return "Unlabeled"
        }
    }

    var shortTitle: String {
        switch self {
        case .production: return "PROD"
        case .staging: return "STAGING"
        case .development: return "DEV"
        case .test: return "TEST"
        case .unlabeled: return "—"
        }
    }

    /// Whether this environment is treated as production-risk (read-only Safe
    /// Mode by default, persistent red indicator).
    var isProduction: Bool { self == .production }

    var accentColor: Color {
        switch self {
        case .production: return Theme.Palette.danger
        case .staging: return Theme.Palette.warning
        case .development: return Theme.Palette.info
        case .test: return Theme.Palette.healthy
        case .unlabeled: return Theme.Palette.textSecondary
        }
    }
}
