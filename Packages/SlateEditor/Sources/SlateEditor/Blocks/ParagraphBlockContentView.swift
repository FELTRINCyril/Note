import SlateModel
import SlateUI
import SwiftUI

/// Rendu en LECTURE SEULE d'un bloc `.paragraph`. L'edition (Phase 5.2) remplacera ce
/// `Text` par `RichTextBlockView` (TextKit 2) sans changer l'appelant : c'est
/// `BlockTreeView`/`BlockContentRouterView` qui font ce choix, ce composant ne fait
/// qu'afficher `RichText.attributedString`.
struct ParagraphBlockContentView: View {
    let text: RichText?
    /// Barre les caracteres (reutilise par `TodoItemContentView` pour un item coche).
    /// `false` par defaut : un paragraphe ordinaire n'est jamais barre.
    var isStrikethrough = false

    var body: some View {
        Text(text?.attributedString ?? AttributedString())
            .slateFont(SlateFont.body)
            .foregroundStyle(SlateColor.textPrimary)
            .lineSpacing(SlateFont.body.size * (SlateGeometry.editorParagraphLineHeight - 1))
            .strikethrough(isStrikethrough, color: SlateColor.textTertiary)
            .textSelection(.enabled)
            .fixedSize(horizontal: false, vertical: true)
    }
}

#Preview("ParagraphBlockContentView - clair") {
    ParagraphBlockContentView(text: RichText(plainText: "Un bloc = un noeud. Le modele porte le type."))
        .padding()
        .background(SlateColor.bgEditor)
        .environment(\.colorScheme, .light)
}

#Preview("ParagraphBlockContentView - sombre") {
    ParagraphBlockContentView(text: RichText(plainText: "Un bloc = un noeud. Le modele porte le type."))
        .padding()
        .background(SlateColor.bgEditor)
        .environment(\.colorScheme, .dark)
}
