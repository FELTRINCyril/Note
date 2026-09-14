import SwiftUI

/// Bloc citation (design/tokens.md §16, artboard F). Composant de PRESENTATION pur : le
/// contenu (texte, potentiellement enrichi) est fourni par l'appelant.
public struct QuoteBlockView<Content: View>: View {
    private let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            RoundedRectangle(cornerRadius: SlateGeometry.quoteBarWidth / 2)
                .fill(SlateColor.quoteBarColor)
                .frame(width: SlateGeometry.quoteBarWidth)
            content
                .slateFont(SlateFont.body)
                .italic()
                .foregroundStyle(SlateColor.quoteText)
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(.vertical, SlateGeometry.decoratedBlockSpacing)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(SlateUIStrings.quoteLabel)
    }
}

#Preview("QuoteBlockView - clair") {
    QuoteBlockView {
        Text("La citation garde la barre quote.barColor de 3 pt et le texte a 65 %.")
    }
    .padding(Spacing.lg)
    .frame(width: 480)
    .background(SlateColor.bgEditor)
    .environment(\.colorScheme, .light)
}

#Preview("QuoteBlockView - sombre") {
    QuoteBlockView {
        Text("Meme citation en sombre : la barre passe a #48484A.")
    }
    .padding(Spacing.lg)
    .frame(width: 480)
    .background(SlateColor.bgEditor)
    .environment(\.colorScheme, .dark)
}
