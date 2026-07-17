import SwiftUI

/// Typographic scale mirroring the Figma hierarchy, expressed with the native
/// SF Pro system font and Dynamic Type so text scales with accessibility
/// settings. (Figma used Inter; SF Pro is the correct native equivalent.)
extension Font {
    /// Large screen title (Figma 26pt semibold).
    static let pcTitle = Font.system(.title, design: .default).weight(.semibold)
    /// Section header (Figma 19pt semibold).
    static let pcSection = Font.system(.title3, design: .default).weight(.semibold)
    /// Large metric number (Figma 24pt semibold).
    static let pcMetric = Font.system(.title2, design: .rounded).weight(.semibold)
    /// Standard body.
    static let pcBody = Font.system(.body)
    /// Emphasised body (row titles).
    static let pcBodyEmphasis = Font.system(.body).weight(.semibold)
    /// Secondary caption (Figma 13pt).
    static let pcCaption = Font.system(.subheadline)
    /// Small label (Figma 10-11pt uppercase).
    static let pcLabel = Font.system(.caption2).weight(.semibold)
    /// Monospaced (document ids, JSON, logs).
    static let pcMono = Font.system(.callout, design: .monospaced)
    static let pcMonoSmall = Font.system(.caption, design: .monospaced)
}
