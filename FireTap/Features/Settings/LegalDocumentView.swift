import SwiftUI

/// In-app legal/support documents rendered from embedded markdown strings.
struct LegalDocumentView: View {
    let document: LegalDocument

    var body: some View {
        ScrollView {
            Text(attributedMarkdown)
                .font(.pcBody)
                .foregroundStyle(Theme.Palette.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Theme.Spacing.xl)
                .textSelection(.enabled)
        }
        .appBackground()
        .navigationTitle(document.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var attributedMarkdown: AttributedString {
        (try? AttributedString(
            markdown: document.markdown,
            options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        )) ?? AttributedString(document.markdown)
    }
}
