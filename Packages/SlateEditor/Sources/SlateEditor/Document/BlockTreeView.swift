import SlateModel
import SlateUI
import SwiftUI

/// Rendu recursif d'un bloc et de ses enfants (imbrication des items de liste,
/// `Block.parent`/`children`). Chaque bloc est enveloppe dans `BlockContainer`
/// (`SlateUI`) : c'est le MEME conteneur qui accueillera `RichTextBlockView` en 5.2,
/// aucune reecriture de cette structure n'est attendue a ce moment-la.
///
/// En 5.1 (lecture seule), `state` reste `.normal` : il n'existe pas encore de notion
/// de focus/selection (Phases 5.2 a 5.6). Le chrome de survol (`BlockHandle`) reste
/// celui, deja fourni par `BlockContainer`, dont les callbacks par defaut sont des
/// no-op -- c'est le contrat du composant tel que livre par `design-integrator` en
/// Phase 5.0, pas une improvisation de cette phase.
struct BlockTreeView: View {
    let block: Block
    /// Freres directs de `block` (memes `parent`), pour calculer le rang d'un item de
    /// liste numerotee. Fournis par l'appelant plutot que recalcules ici : evite de
    /// remonter `block.parent?.children`/`note.blocks` a chaque noeud de l'arbre.
    let siblings: [Block]
    let indentLevel: Int
    let strings: NoteEditorStrings

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            BlockContainer(
                isEmpty: block.text?.isEmpty ?? true,
                firstLineHeight: firstLineHeight,
                blockID: block.id.uuidString
            ) {
                BlockContentRouterView(block: block, numberedRank: numberedRank, strings: strings)
            }
            .padding(.leading, CGFloat(indentLevel) * Self.indentStep)

            let childBlocks = BlockOrdering.children(of: block)
            ForEach(childBlocks, id: \.id) { child in
                BlockTreeView(
                    block: child,
                    siblings: childBlocks,
                    indentLevel: indentLevel + 1,
                    strings: strings
                )
            }
        }
    }

    private var numberedRank: Int {
        guard block.type == .numberedList else { return 1 }
        return BlockOrdering.numberedListRank(of: block, among: siblings)
    }

    private var firstLineHeight: CGFloat {
        switch BlockRenderRouting.kind(for: block.type) {
        case let .heading(level):
            HeadingStyle.firstLineHeight(forLevel: level)
        default:
            SlateFont.body.size * SlateGeometry.editorParagraphLineHeight
        }
    }

    /// GAP DE TOKEN SIGNALE (voir rapport de livraison) : pas de pas d'indentation
    /// dedie a l'editeur dans `SlateGeometry`. `Spacing.lg` (16 pt) est reutilise en
    /// attendant, sur le meme principe que `sidebarIndentStep` (aussi 16 pt) pour la
    /// sidebar -- une valeur d'espacement EXISTANTE, pas une constante inventee.
    private static let indentStep = Spacing.lg
}
