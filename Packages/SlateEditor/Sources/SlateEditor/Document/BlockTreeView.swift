import AppKit
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
/// `editorController.focusedBlockID`/la plage de selection courante. Depuis la 5.6,
/// **tous les types de blocs rendus** peuvent etre selectionnes/focalises au clavier --
/// avant cette sous-etape, `.focused`/`.selected` et `.focusable` restaient restreints
/// aux blocs `.paragraph` (seul type reellement editable), ce qui rendait le menu de
/// bloc INATTEIGNABLE au clavier pour un titre, une citation, un item de liste ou un
/// separateur (trou d'accessibilite signale par l'agent de la sous-etape 5.4). La
/// restriction est levee : `rangePositions` (calcule UNE SEULE FOIS par
/// `NoteDocumentView`, voir `EditorController.selectionRangePositions()`) porte
/// desormais la selection pour n'importe quel type de bloc.
///
/// ## Selection multi-blocs (sous-etape 5.6) : deux gestes souris, distincts du glisser
/// de DEPLACEMENT de la poignee
/// - **Clic + Maj** (`extendSelectionTapGesture`) : `TapGesture().modifiers(.shift)`,
///   un mecanisme SwiftUI totalement independant de `BlockHandle.draggable(_:)`
///   (session `Transferable`/`NSItemProvider`, Phase 10) -- aucun risque de confusion,
///   les deux ne partagent ni le meme geste ni la meme vue (la poignee est un petit
///   bouton dans la gouttiere, ce `TapGesture` couvre tout le bloc).
/// - **Glisser** (`selectionDragGesture`) : un `DragGesture` SwiftUI attache au CONTENU
///   du bloc (pas a la poignee). Sa distinction avec le glisser de DEPLACEMENT de la
///   poignee est structurelle, pas comportementale : `.draggable(_:)` sur
///   `BlockHandle` capture sa PROPRE session de glisser-depose native au niveau de son
///   bouton, jamais partagee avec un `DragGesture` SwiftUI attache ailleurs dans
///   l'arbre de vues -- les deux gestes ne peuvent PHYSIQUEMENT pas se declencher sur
///   le meme evenement. Sa distinction avec la selection de TEXTE native (a
///   l'INTERIEUR d'un `NSTextView`, spec E4 : "la selection de texte reste locale au
///   bloc") est, elle, comportementale et VOULUE : `continueBlockRangeDrag(pointerLocation:)`
///   ne fait RIEN tant que le point courant du glisser n'a pas quitte le bloc ou il a
///   commence (voir sa documentation) -- glisser pour selectionner du texte DANS un
///   seul bloc ne declenche donc jamais l'aplat de plage, exactement la regle de la
///   spec E4 ("des que la selection franchit une frontiere de bloc...").
struct BlockTreeView: View {
    let block: Block
    /// Freres directs de `block` (memes `parent`), pour calculer le rang d'un item de
    /// liste numerotee. Fournis par l'appelant plutot que recalcules ici : evite de
    /// remonter `block.parent?.children`/`note.blocks` a chaque noeud de l'arbre.
    let siblings: [Block]
    let indentLevel: Int
    let strings: NoteEditorStrings
    let editorController: EditorController
    /// Position de `block` (et de tous les autres blocs actuellement rendus) dans la
    /// plage de selection courante, calculee UNE SEULE FOIS par `NoteDocumentView`
    /// (voir sa documentation) -- jamais recalculee ici, pour rester O(1) par bloc sur
    /// une note de 200+ blocs.
    let rangePositions: [UUID: SlateBlockRangePosition]

    /// Focus clavier SwiftUI (distinct du focus AppKit du `NSTextView`, voir
    /// `RichTextEditingTextView`) : necessaire uniquement pour capter Entree/Espace sur
    /// un bloc SELECTIONNE SEUL (pas en edition), ou aucun `NSTextView` n'est premier
    /// repondant -- voir `.onKeyPress` ci-dessous.
    @FocusState private var isSelectionKeyCaptureFocused: Bool

    /// Menu de bloc ouvert par la poignee (sous-etape 5.4) : au CLIC souris (via
    /// `BlockHandle.onMenu`) ou au CLAVIER (voir "Acces clavier" ci-dessous).
    @State private var isBlockMenuPresented = false

    /// Vrai pendant qu'un glisser de selection est en cours et a DEJA franchi la
    /// frontiere de ce bloc (voir `selectionDragGesture`) -- pilote uniquement l'appel
    /// a `beginBlockRangeDrag(at:)`, une seule fois par glisser.
    @State private var isTrackingSelectionDrag = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            BlockContainer(
                state: blockState,
                rangePosition: rangePositions[block.id] ?? .single,
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
            .background(
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: BlockFramePreferenceKey.self,
                        value: [block.id: proxy.frame(in: .named(NoteDocumentView.blockListCoordinateSpace))]
                    )
                }
            )
            .simultaneousGesture(selectionDragGesture)
            .simultaneousGesture(extendSelectionTapGesture)
            .simultaneousGesture(plainSelectTapGesture)
            .popover(isPresented: $isBlockMenuPresented) { blockMenu }
            .focusable(true)
            .focused($isSelectionKeyCaptureFocused)
            // Acces clavier au menu de bloc (point 5 de la sous-etape 5.4, generalise a
            // tout type de bloc en 5.6) : une fois qu'un bloc est SELECTIONNE SEUL (Tab
            // jusqu'a son texte puis Echap pour un paragraphe ; simple clic pour tout
            // autre type -- voir `EditorController.selectBlock(_:)`), Espace ouvre
            // EXACTEMENT le meme menu que la poignee souris, dont chaque entree reste
            // ensuite atteignable au clavier/VoiceOver (boutons natifs dans un
            // `.popover`).
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
                isSelectionKeyCaptureFocused = newValue == block.id
            }
            // Annonce le raccourci Espace UNIQUEMENT quand il devient reellement
            // actionnable (bloc selectionne seul) : repeter cette indication sur chaque
            // bloc lu en survol/navigation ordinaire alourdirait inutilement
            // l'experience VoiceOver.
            .accessibilityHint(editorController.selectedBlockID == block.id ? EditorStrings.blockMenuAccessibilityHint : "")

            let childBlocks = BlockOrdering.children(of: block)
            ForEach(childBlocks, id: \.id) { child in
                BlockTreeView(
                    block: child,
                    siblings: childBlocks,
                    indentLevel: indentLevel + 1,
                    strings: strings,
                    editorController: editorController,
                    rangePositions: rangePositions
                )
            }
        }
    }

    // MARK: - Gestes de selection (sous-etape 5.6, voir la documentation de tete de fichier)

    /// Clic + Maj : etend la selection jusqu'a `block`. `TapGesture().modifiers(.shift)`
    /// ne se reconnait QUE si Maj est deja tenu au moment du clic -- un clic simple ne
    /// declenche jamais cette gesture, voir `plainSelectTapGesture` pour ce cas.
    private var extendSelectionTapGesture: some Gesture {
        TapGesture().modifiers(.shift).onEnded {
            editorController.extendSelection(to: block)
        }
    }

    /// Clic simple (sans Maj) : selectionne `block` SEUL. Necessaire pour tout type de
    /// bloc SANS `NSTextView` (titre, citation, item de liste, separateur...), qui
    /// n'ont pas de geste "Echap" equivalent pour etablir une selection (point 3 de la
    /// sous-etape 5.6) -- voir `EditorController.selectBlock(_:)`. Ignore le clic si
    /// Maj est tenu (deja traite par `extendSelectionTapGesture` ci-dessus) : les deux
    /// gestes sont attaches en `.simultaneousGesture`, donc potentiellement reconnus
    /// tous les deux sur le MEME clic sans cette garde, ce qui ecraserait a tort
    /// l'extension par une simple selection.
    private var plainSelectTapGesture: some Gesture {
        TapGesture().onEnded {
            guard NSEvent.modifierFlags.contains(.shift) == false else { return }
            editorController.selectBlock(block)
        }
    }

    /// Glisser : voir la documentation de tete de fichier pour la distinction avec le
    /// glisser de deplacement de la poignee et avec la selection de texte native.
    /// `minimumDistance` volontairement superieur au seuil par defaut (0) pour ne pas
    /// interferer avec un simple clic (capture par les deux `TapGesture` ci-dessus).
    private var selectionDragGesture: some Gesture {
        DragGesture(minimumDistance: 6, coordinateSpace: .named(NoteDocumentView.blockListCoordinateSpace))
            .onChanged { value in
                if !isTrackingSelectionDrag {
                    isTrackingSelectionDrag = true
                    editorController.beginBlockRangeDrag(at: block)
                }
                editorController.continueBlockRangeDrag(pointerLocation: value.location)
            }
            .onEnded { _ in
                isTrackingSelectionDrag = false
                editorController.endBlockRangeDrag()
            }
    }

    // MARK: - Menu de bloc (unique ou en lot -- sous-etape 5.6, point 5)

    /// `true` si `block` fait partie d'une plage de PLUSIEURS blocs actuellement
    /// selectionnes : dans ce cas le menu de bloc doit agir sur toute la plage, avec des
    /// libelles qui le refletent (docs/05_editeur_blocs.md, sous-etape 5.6 : "ne pas
    /// laisser un menu qui dit 'Supprimer' en en supprimant sept").
    private var isPartOfMultiBlockSelection: Bool {
        rangePositions.count > 1 && rangePositions[block.id] != nil
    }

    @ViewBuilder
    private var blockMenu: some View {
        if isPartOfMultiBlockSelection {
            BlockMenuView(
                currentTypeLabel: EditorStrings.blockTypeLabel(block.type),
                selectionCount: rangePositions.count,
                availableConversionTargets: editorController.availableConversionTargetsForSelectionRange(),
                canMoveUp: editorController.canMoveSelectionRangeUp(),
                canMoveDown: editorController.canMoveSelectionRangeDown(),
                onConvert: { newType in
                    isBlockMenuPresented = false
                    editorController.convertSelectionRange(to: newType)
                },
                onDuplicate: {},
                onMoveUp: { isBlockMenuPresented = false; editorController.moveSelectionRangeUp() },
                onMoveDown: { isBlockMenuPresented = false; editorController.moveSelectionRangeDown() },
                onDelete: { isBlockMenuPresented = false; editorController.deleteSelectionRange() }
            )
        } else {
            BlockMenuView(
                currentTypeLabel: EditorStrings.blockTypeLabel(block.type),
                availableConversionTargets: BlockConversion.availableTargets(for: block),
                canMoveUp: BlockOrdering.siblings(of: block).first?.id != block.id,
                canMoveDown: BlockOrdering.siblings(of: block).last?.id != block.id,
                onConvert: { newType in
                    isBlockMenuPresented = false
                    editorController.convertBlock(block, to: newType)
                },
                onDuplicate: { isBlockMenuPresented = false; editorController.duplicateBlock(block) },
                onMoveUp: { isBlockMenuPresented = false; editorController.moveBlockUp(block) },
                onMoveDown: { isBlockMenuPresented = false; editorController.moveBlockDown(block) },
                onDelete: { isBlockMenuPresented = false; editorController.deleteBlock(block) }
            )
        }
    }

    private var blockState: SlateBlockState {
        if editorController.focusedBlockID == block.id { return .focused }
        if rangePositions[block.id] != nil { return .selected }
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

    /// Pas d'indentation par niveau de liste dans l'editeur. Equivalent
    /// `SlateGeometry.editorListIndentStep` (design/tokens.md §16 : `editor.listIndentStep`,
    /// 24 pt), ajoute en Phase 5 pour combler le gap signale par l'agent 5.1 -- ce site
    /// reutilisait `Spacing.lg` (16 pt) en attendant.
    private static let indentStep = SlateGeometry.editorListIndentStep
}
