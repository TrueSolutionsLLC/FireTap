import SwiftUI

/// Honest, reusable state views. Every failure explains what happened and what
/// the user can do; nothing ever silently shows fake content.

struct LoadingStateView: View {
    var rows: Int = 5
    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            ForEach(0..<rows, id: \.self) { _ in
                Card {
                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        SkeletonBlock(height: 18).frame(maxWidth: 180)
                        SkeletonBlock(height: 12).frame(maxWidth: 120)
                    }
                }
            }
        }
        .accessibilityLabel("Loading")
    }
}

struct EmptyStateView: View {
    let title: String
    let message: String
    var systemImage: String = "tray"
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: systemImage)
        } description: {
            Text(message)
        } actions: {
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.Palette.accent)
            }
        }
    }
}

/// Renders an `APIError` as an actionable state, with special treatment for
/// permission and not-configured cases.
struct ErrorStateView: View {
    let error: APIError
    var retry: (() -> Void)?
    var reauth: (() -> Void)?

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: symbol)
        } description: {
            Text(error.userMessage)
        } actions: {
            switch error {
            case .unauthorized, .notAuthenticated:
                if let reauth {
                    Button("Sign in again", action: reauth)
                        .buttonStyle(.borderedProminent)
                        .tint(Theme.Palette.accent)
                }
            case .permissionDenied:
                EmptyView()
            default:
                if let retry {
                    Button("Try again", action: retry)
                        .buttonStyle(.borderedProminent)
                        .tint(Theme.Palette.accent)
                }
            }
        }
    }

    private var title: String {
        switch error {
        case .permissionDenied: return "Not permitted"
        case .unauthorized, .notAuthenticated: return "Session expired"
        case .rateLimited: return "Rate limited"
        case .notFound: return "Not found"
        case .transport: return "Can't reach Google"
        default: return "Something went wrong"
        }
    }

    private var symbol: String {
        switch error {
        case .permissionDenied: return "hand.raised.slash"
        case .unauthorized, .notAuthenticated: return "person.crop.circle.badge.exclamationmark"
        case .rateLimited: return "hourglass"
        case .notFound: return "questionmark.folder"
        case .transport: return "wifi.slash"
        default: return "exclamationmark.triangle"
        }
    }
}

/// Shown when OAuth has not been configured with a real client id.
struct NotConfiguredStateView: View {
    var body: some View {
        ContentUnavailableView {
            Label("Sign-in not configured", systemImage: "gearshape.2")
        } description: {
            Text("Add your Google OAuth client id to Config/Secrets.xcconfig, then rebuild. See docs/OAUTH_SETUP.md for a step-by-step guide.")
        }
    }
}

/// A small inline permission/availability note for dashboard cards.
struct CardUnavailableNote: View {
    let message: String
    var systemImage: String = "lock"
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
            Text(message)
        }
        .font(.pcCaption)
        .foregroundStyle(Theme.Palette.textSecondary)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
