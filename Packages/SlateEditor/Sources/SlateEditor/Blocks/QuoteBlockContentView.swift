import SlateModel
import SlateUI
import SwiftUI

/// Citation (`BlockType.quote`), lecture seule : barre laterale `SlateColor.
/// quoteBarColor` + texte du corps.
struct QuoteBlockContentView: View {
    let text: RichText?

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Capsule(style: .continuous)
                .fill(SlateColor.quoteBarColor)
                .frame(width: SlateGeometry.editorCaretWidth)
            ParagraphBlockContentView(text: text)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Citation")
    }
}

#Preview("QuoteBlockContentView - clair") {
    QuoteBlockContentView(text: RichText(plainText: "La selection de texte reste locale au bloc."))
        .padding()
        .frame(width: 400)
        .background(SlateColor.bgEditor)
        .environment(\.colorScheme, .light)
}

#Preview("QuoteBlockContentView - sombre") {
    QuoteBlockContentView(text: RichText(plainText: "La selection de texte reste locale au bloc."))
        .padding()
        .frame(width: 400)
        .background(SlateColor.bgEditor)
        .environment(\.colorScheme, .dark)
}
