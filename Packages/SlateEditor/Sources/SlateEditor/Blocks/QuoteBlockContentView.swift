import SlateModel
import SlateUI
import SwiftUI

/// Citation (`BlockType.quote`), EDITABLE depuis la Phase 8 (docs/08, "barre laterale
/// gauche, texte en retrait, editable") -- meme motif que les autres blocs textuels de
/// cette phase : `QuoteBlockView` (`SlateUI`) porte le chrome (barre + retrait),
/// `RichTextBlockView` porte l'edition reelle. `QuoteBlockView.italic()` (modificateur
/// SwiftUI applique a son `content`) reste sans effet sur le rendu INTERNE d'un
/// `NSViewRepresentable` -- ecart cosmetique assume (le corps de citation reste en
/// romain, pas en italique) : voir le rapport de livraison.
struct QuoteBlockContentView: View {
    let block: Block
    let editorController: EditorController

    var body: some View {
        QuoteBlockView {
            RichTextBlockView(block: block, editorController: editorController)
        }
    }
}
