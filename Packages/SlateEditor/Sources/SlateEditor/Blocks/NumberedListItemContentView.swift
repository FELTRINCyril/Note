import SlateModel
import SlateUI
import SwiftUI

/// Item de liste numerotee (`BlockType.numberedList`), EDITABLE depuis la Phase 8 -- meme
/// motif que `BulletedListItemContentView`. `rank` (1-based) est calcule par
/// `BlockOrdering.numberedListRank(of:among:)` (dans `BlockTreeView`), pas par cette vue :
/// elle se contente d'afficher un entier deja determine, testable sans SwiftUI. `level`
/// pilote le STYLE de numerotation cyclique (chiffres/lettres/romains, voir
/// `SlateListMarker`) et l'indentation, meme raison que `BulletedListItemContentView`.
struct NumberedListItemContentView: View {
    let block: Block
    let editorController: EditorController
    let rank: Int
    let level: Int

    var body: some View {
        ListItemView(.ordered(index: rank, level: level)) {
            RichTextBlockView(block: block, editorController: editorController)
        }
    }
}
