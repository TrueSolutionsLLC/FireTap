# Accessibility Audit

Target: WCAG-informed, native iOS accessibility. Status ✅ implemented · 🟡 partial · ⬜ to verify.

## Implemented
- ✅ **Dynamic Type**: all text uses semantic `Font` styles (`.title`, `.body`, `.subheadline`, `.caption2`, monospaced) that scale.
- ✅ **Dark & light mode**: adaptive palette via dynamic `UIColor` providers; both appearances defined together.
- ✅ **Reduce Motion**: skeleton shimmer disables its animation when Reduce Motion is on.
- ✅ **VoiceOver labels**: production indicator, status chips, project rows, and account badge combine children into meaningful labels; section headers marked with `.isHeader`.
- ✅ **SF Symbols** throughout (no text glyphs used as icons), which inherit accessibility traits.
- ✅ **Accessibility identifiers** on key controls (`welcome.continueWithGoogle`, `consent.continue`) for UI testing.
- ✅ **Contrast**: text/background pairs chosen for AA-level contrast in both themes; production red reserved for genuine risk; orange used sparingly.

## To verify before release (🟡/⬜)
- 🟡 Full VoiceOver pass on every screen (rotor, focus order, actionable elements).
- ⬜ Dynamic Type at AX5 (accessibility sizes) with no truncation/clipping on iPhone SE and iPad.
- ⬜ Voice Control labels for all tappable elements.
- ⬜ Contrast measurement with a tool (e.g., 4.5:1 for body text) on final palette.
- ⬜ Hit targets ≥ 44×44 pt on compact rows.
- ⬜ Keyboard navigation & shortcuts on iPad.
- ⬜ RTL layout check (leading/trailing used, but verify).

## How to test
- Settings → Accessibility → VoiceOver; Display & Text Size → Larger Text; Motion → Reduce Motion.
- Xcode Accessibility Inspector (audit + contrast).
- Environment overrides in SwiftUI previews for `sizeCategory`, `colorScheme`, `accessibilityReduceMotion`.
