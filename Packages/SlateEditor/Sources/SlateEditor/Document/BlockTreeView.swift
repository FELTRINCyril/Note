import SlateModel
import SlateUI
import SwiftUI

/// Rendu recursif d'un bloc et de ses enfants (imbrication des items de liste,
/// `Block.parent`/`children`). Chaque bloc est enveloppe dans `BlockContainer`
/// (`SlateUI`) : c'est le MEME conteneur qui accueillera `RichTextBlockView` en 5.2,
/// aucune reecriture de cette structure n'est attendue a ce moment-la.
///
/// En 5.1 (lecture seule), `state` restait toujours `.normal` : il n'existait pas
/// encore de notion de focus/selection (Phases 5.2 a 5.6). Depuis la 5.3, `state` lit
/// `editorController.focusedBlockID`/`selectedBlockID` (source unique, voir
/// `EditorController`) : `.focused` pendant l'edition, `.selected` apres un Echap
/// (spec E4 : "Echap sort de l'edition et selectionne le bloc entier"). Ces deux etats
/// restent restreints aux blocs `.paragraph` : seul type reellement editable a ce stade
/// de la Phase 5 (voir `BlockContentRouterView`), un bloc qui ne peut pas entrer en
/// edition n'a pas de sens a "selectionner en vue d'y entrer".
struct BlockTreeView: View {
    let block: Block
    /// Freres directs de `block` (memes `parent`), pour calculer le rang d'un item de
    /// liste numerotee. Fournis par l'appelant plutot que recalcules ici : evite de
    /// remonter `block.parent?.children`/`note.blocks` a chaque noeud de l'arbre.
    let siblings: [Block]
    let indentLevel: Int
    let strings: NoteEditorStrings
    let editorController: EditorController

    /// Focus clavier SwiftUI (distinct du focus AppKit du `NSTextView`, voir
    /// `RichTextEditingTextView`) : necessaire uniquement pour capter Entree/Espace sur
    /// un bloc SELECTIONNE (pas en edition), ou aucun `NSTextView` n'est premier
    /// repondant -- voir `.onKeyPress` ci-dessous.
    @FocusState private var isSelectionKeyCaptureFocused: Bool

    /// Menu de bloc ouvert par la poignee (sous-etape 5.4) : au CLIC souris (via
    /// `BlockHandle.onMenu`) ou au CLAVIER (voir "Acces clavier" ci-dessous).
    @State private var isBlockMenuPresented = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            BlockContainer(
                state: blockState,
                isEmpty: block.text?.isEmpty ?? true,
                placeholder: EditorStrings.paragraphPlaceholder,
                firstLineHeight: firstLineHeight,
                blockID: block.id.uuidString,
                onInsert: { editorController.insertBlockBelow(block) },
                onMenu: { isBlockMenuPresented = true },
                content: {
                    BlockContentRouterView(
                        block: block,
                        numberedRank: numberedRank,
                        strings: strings,
                        editorController: editorController
                    )
                }
            )
            .padding(.leading, CGFloat(indentLevel) * Self.indentStep)
            .popover(isPresented: $isBlockMenuPresented) {
                BlockMenuView(
                    canMoveUp: BlockOrdering.siblings(of: block).first?.id != block.id,
                    canMoveDown: BlockOrdering.siblings(of: block).last?.id != block.id,
                    onDuplicate: { isBlockMenuPresented = false; editorController.duplicateBlock(block) },
                    onMoveUp: { isBlockMenuPresented = false; editorController.moveBlockUp(block) },
                    onMoveDown: { isBlockMenuPresented = false; editorController.moveBlockDown(block) },
                    onDelete: { isBlockMenuPresented = false; editorController.deleteBlock(block) }
                )
            }
            .focusable(block.type == .paragraph)
            .focused($isSelectionKeyCaptureFocused)
            // Acces clavier au menu de bloc (point 5 de la sous-etape 5.4) : une fois
            // qu'un bloc est SELECTIONNE (Tab jusqu'a son texte puis Echap -- geste
            // deja pose en 5.3), Espace ouvre EXACTEMENT le meme menu que la poignee
            // souris, dont chaque entree reste ensuite atteignable au clavier/VoiceOver
            // (boutons natifs dans un `.popover`). LIMITE ASSUMEE : `selectedBlockID`
            // reste restreint aux blocs `.paragraph` depuis la 5.3 (seul type
            // reellement editable a ce stade de la Phase 5) -- les autres types
            // (titre, citation, code, separateur...) ne sont donc accessibles au menu
            // qu'au survol souris jusqu'a ce que la selection soit generalisee (prevu
            // en 5.6, "Selection multi-blocs").
            .onKeyPress(.space) {
                guard editorController.selectedBlockID == block.id else { return .ignored }
                isBlockMenuPresented = true
                return .handled
            }
            .onKeyPress(.return) {
                guard editorController.selectedBlockID == block.id else { return .ignored }
                editorController.handleEnterOnSelectedBlock()
                return .handled
            }
            .onChange(of: editorController.selectedBlockID) { _, newValue in
                isSelectionKeyCaptureFocused = block.type == .paragraph && newValue == block.id
            }
            // Annonce le raccourci Espace UNIQUEMENT quand il devient reellement
            // actionnable (bloc selectionne) : repeter cette indication sur chaque
            // bloc lu en survol/navigation ordinaire alourdirait inutilement
            // l'experience VoiceOver (voir la limite documentee ci-dessus).
            .accessibilityHint(editorController.selectedBlockID == block.id ? EditorStrings.blockMenuAccessibilityHint : "")

            let childBlocks = BlockOrdering.children(of: block)
            ForEach(childBlocks, id: \.id) { child in
                BlockTreeView(
                    block: child,
                    siblings: childBlocks,
                    indentLevel: indentLevel + 1,
                    strings: strings,
                    editorController: editorController
                )
            }
        }
    }

    private var blockState: SlateBlockState {
        guard block.type == .paragraph else { return .normal }
        if editorController.focusedBlockID == block.id { return .focused }
        if editorController.selectedBlockID == block.id { return .selected }
        return .normal
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
