import SlateModel
import SlateUI
import SwiftUI

/// Item de liste a puces (`BlockType.bulletedList`), EDITABLE depuis la Phase 8 (docs/08,
/// "Listes" -- meme travail que les titres en Phase 7 : le texte lu seul est remplace par
/// `RichTextBlockView`, enveloppe dans `ListItemView` (`SlateUI`) pour la puce). `level`
/// pilote a la fois la FORME de la puce (cyclique par niveau -- rond/chevron/carre, voir
/// `SlateListMarker`) et l'indentation visuelle : voir `BlockTreeView`, qui n'applique
/// PAS sa propre indentation generique pour ce type (elle serait doublee).
struct BulletedListItemContentView: View {
    let block: Block
    let editorController: EditorController
    let level: Int

    var body: some View {
        ListItemView(.bullet(level: level)) {
            RichTextBlockView(block: block, editorController: editorController)
        }
    }
}
