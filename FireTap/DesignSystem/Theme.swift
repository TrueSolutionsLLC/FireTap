import SwiftUI

/// Design tokens derived from the Figma "Firebase Mobile Console" file, adapted
/// into a native, adaptive (light + dark) palette. Colors are defined in code
/// via dynamic `UIColor` providers so both appearances are always in sync.
enum Theme {

    // MARK: Palette

    enum Palette {
        /// App base background.
        static let background = dynamic(dark: 0x090B0E, light: 0xF4F5F7)
        /// Navigation / tab bar background.
        static let bar = dynamic(dark: 0x0E1014, light: 0xFFFFFF)
        /// Card / grouped-content surface.
        static let surface = dynamic(dark: 0x13161C, light: 0xFFFFFF)
        /// A slightly raised surface (used for nested rows).
        static let surfaceRaised = dynamic(dark: 0x1B1F27, light: 0xF0F1F4)
        /// Hairline separators.
        static let separator = dynamic(dark: 0x242A33, light: 0xE2E5EA)

        static let textPrimary = dynamic(dark: 0xF7FAFF, light: 0x0B0D10)
        static let textSecondary = dynamic(dark: 0x8C99AD, light: 0x5B6472)
        static let textTertiary = dynamic(dark: 0x5C6675, light: 0x8A93A1)

        /// Priority actions only — used sparingly.
        static let accent = dynamic(dark: 0xFF851F, light: 0xE86A00)
        /// Healthy / Safe.
        static let healthy = dynamic(dark: 0x40D68C, light: 0x1E9E63)
        /// Informational.
        static let info = dynamic(dark: 0x408CFF, light: 0x1E6FE0)
        /// Genuine production risk only.
        static let danger = dynamic(dark: 0xFF4D47, light: 0xD32017)
        /// Caution / warnings.
        static let warning = dynamic(dark: 0xFFB23E, light: 0xC77A00)

        /// Tinted container backgrounds.
        static let healthyContainer = dynamic(dark: 0x143326, light: 0xDFF4E9)
        static let dangerContainer = dynamic(dark: 0x291312, light: 0xFBE3E1)
        static let infoContainer = dynamic(dark: 0x121F33, light: 0xE1ECFB)
        static let warningContainer = dynamic(dark: 0x2A2113, light: 0xFBF0DC)
    }

    // MARK: Radii

    enum Radius {
        static let small: CGFloat = 11
        static let medium: CGFloat = 18
        static let large: CGFloat = 22
        static let card: CGFloat = 18
        static let chip: CGFloat = 10
    }

    // MARK: Spacing

    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 28
    }

    // MARK: Helpers

    private static func dynamic(dark: Int, light: Int) -> Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(rgb: dark) : UIColor(rgb: light)
        })
    }
}

extension UIColor {
    /// Creates an opaque color from a 24-bit RGB integer, e.g. `0xFF851F`.
    convenience init(rgb: Int) {
        self.init(
            red: CGFloat((rgb >> 16) & 0xFF) / 255.0,
            green: CGFloat((rgb >> 8) & 0xFF) / 255.0,
            blue: CGFloat(rgb & 0xFF) / 255.0,
            alpha: 1.0
        )
    }
}
