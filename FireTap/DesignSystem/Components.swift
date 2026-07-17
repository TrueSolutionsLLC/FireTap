import SwiftUI

// MARK: - Card

/// Rounded surface container matching the Figma card style.
struct Card<Content: View>: View {
    var padding: CGFloat = Theme.Spacing.lg
    var background: Color = Theme.Palette.surface
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(background, in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
    }
}

// MARK: - Section header

struct SectionHeader: View {
    let title: String
    var trailing: String?
    var trailingAction: (() -> Void)?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.pcSection)
                .foregroundStyle(Theme.Palette.textPrimary)
            Spacer(minLength: Theme.Spacing.sm)
            if let trailing {
                Button(trailing) { trailingAction?() }
                    .font(.pcCaption)
                    .foregroundStyle(Theme.Palette.accent)
                    .disabled(trailingAction == nil)
            }
        }
        .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - Status chip

struct StatusChip: View {
    let text: String
    var systemImage: String?
    var color: Color = Theme.Palette.healthy
    var container: Color = Theme.Palette.healthyContainer

    var body: some View {
        HStack(spacing: 4) {
            if let systemImage {
                Image(systemName: systemImage).font(.caption2.weight(.bold))
            }
            Text(text).font(.pcLabel)
        }
        .foregroundStyle(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(container, in: Capsule())
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Production indicator

/// Persistent production banner that must remain visible while a production
/// project is open.
struct ProductionIndicator: View {
    var readOnly: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.shield.fill")
            Text("PRODUCTION")
                .font(.pcLabel)
            if readOnly {
                Text("• READ-ONLY")
                    .font(.pcLabel)
                    .opacity(0.9)
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity)
        .background(Theme.Palette.danger)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(readOnly ? "Production project, read-only Safe Mode" : "Production project")
    }
}

// MARK: - Skeleton

/// Simple shimmering skeleton block for loading states. Honors Reduce Motion.
struct SkeletonBlock: View {
    var height: CGFloat = 16
    var cornerRadius: CGFloat = 8
    @State private var phase: CGFloat = -1
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Theme.Palette.surfaceRaised)
            .frame(height: height)
            .overlay(shimmer)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                    phase = 2
                }
            }
            .accessibilityHidden(true)
    }

    private var shimmer: some View {
        GeometryReader { geo in
            LinearGradient(
                colors: [.clear, Theme.Palette.textTertiary.opacity(0.25), .clear],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: geo.size.width * 0.6)
            .offset(x: geo.size.width * phase)
            .opacity(reduceMotion ? 0 : 1)
        }
    }
}

// MARK: - App background

struct AppBackground: ViewModifier {
    func body(content: Content) -> some View {
        content.background(Theme.Palette.background.ignoresSafeArea())
    }
}

extension View {
    func appBackground() -> some View { modifier(AppBackground()) }
}
