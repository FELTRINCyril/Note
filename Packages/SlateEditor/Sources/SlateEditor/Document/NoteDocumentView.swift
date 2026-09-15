import SlateModel
import SlateUI
import SwiftData
import SwiftUI

/// Rendu complet d'une note : en-tete (`NoteHeaderView`) + corps de blocs, tries par
/// `order` et imbriques selon `parent`/`children` (`BlockOrdering`). Le titre
/// (`NoteHeaderView`) et les blocs paragraphe (`RichTextBlockView`, Phase 5.2) sont
/// editables ; les autres types de bloc restent en lecture seule jusqu'a leurs phases
/// respectives (5.5 conversion, 6-8 blocs riches).
///
/// ## Point d'entree unique de la Phase 5.1
/// C'est cette vue que `SlateFeatures` doit instancier a la place du placeholder de
/// colonne de detail quand une note est selectionnee (voir `docs/05_editeur_blocs.md`,
/// sous-etape 5.1, point 6).
///
/// `metadataLine` est fourni DEJA FORME par l'appelant (date relative + heure
/// localisees, cf. `NoteRelativeDateFormatter` de `SlateFeatures`) : `SlateEditor` ne
/// doit pas dependre de `SlateFeatures` (sens des dependances, voir
/// `docs/00_architecture.md`), donc ne porte aucune logique de `Calendar`/`Locale`.
/// Le compte de mots, lui, EST calcule ici (`WordCounter`, a partir de
/// `Note.plainText`) : c'est une pure derivation du modele, pas une decision de
/// presentation liee a la locale.
public struct NoteDocumentView: View {
    /// Nom de la `coordinateSpace` partagee par tous les blocs de la colonne de texte
    /// (sous-etape 5.6, glisser de selection) -- voir `BlockFramePreferenceKey` et
    /// `EditorController.blockFrames`.
    static let blockListCoordinateSpace = "slate.editor.blockList"

    private let note: Note
    private let metadataLine: String
    private let strings: NoteEditorStrings
    private let onAddIcon: () -> Void
    private let onAddCover: () -> Void
    /// Navigation vers une autre note (Phase 16) : clic sur un bloc `pageLink`, un lien
    /// inline `slate://note/<uuid>`, ou un backlink. Meme fermeture branchee sur
    /// `EditorController.onNavigateToNote`, voir sa documentation.
    private let onNavigateToNote: (Note) -> Void

    /// Notes qui mentionnent la note courante (Phase 16, "Backlinks"), recalculees a
    /// chaque changement de note affichee (`task(id:)` plus bas), PAS a chaque frappe --
    /// un nouveau lien cree pendant la consultation de la cible n'apparait qu'a la
    /// prochaine ouverture (limite connue, voir le rapport de livraison).
    @State private var backlinkNotes: [Note] = []

    /// Source UNIQUE du cycle de vie des blocs pour toute la note (focus d'edition,
    /// selection, insertion/fusion/split/suppression, navigation -- voir
    /// `EditorController`). Remplace le simple `UUID?` local de la 5.2 : la coordination
    /// clavier complete vit desormais ici, sans changer la structure de vues en aval
    /// (`BlockTreeView`/`BlockContentRouterView` recoivent directement `editorController`).
    @State private var editorController: EditorController

    @Environment(\.modelContext) private var modelContext

    public init(
        note: Note,
        metadataLine: String,
        strings: NoteEditorStrings = NoteEditorStrings(),
        onAddIcon: @escaping () -> Void = {},
        onAddCover: @escaping () -> Void = {},
        onNavigateToNote: @escaping (Note) -> Void = { _ in }
    ) {
        self.note = note
        self.metadataLine = metadataLine
        self.strings = strings
        self.onAddIcon = onAddIcon
        self.onAddCover = onAddCover
        self.onNavigateToNote = onNavigateToNote
        self._editorController = State(initialValue: EditorController(note: note))
    }

    public var body: some View {
        // Le `ModelContext` reel n'est disponible que via `@Environment`, jamais a
        // l'`init` (voir `EditorController.updateModelContext`) : idempotent, sans
        // effet observable si la valeur n'a pas change.
        editorController.updateModelContext(modelContext)
        editorController.onNavigateToNote = onNavigateToNote

        // `ScrollViewReader` est le complement OBLIGATOIRE du `LazyVStack` ci-dessous,
        // pas une simple amelioration : voir la documentation de tete de
        // `scrollToFocusedBlockIfNeeded(_:proxy:)` pour la raison precise (navigation
        // clavier vers un bloc pas encore materialise).
        return ScrollViewReader { scrollProxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    NoteHeaderView(
                        note: note,
                        metadataLine: metadataLine,
                        strings: strings,
                        onAddIcon: onAddIcon,
                        onAddCover: onAddCover
                    )

                    EditorContentColumn {
                        // `LazyVStack` (Perf, revue finale de Phase 5 : "recycler/paresser
                        // le rendu pour les notes longues") remplace le `VStack` de la
                        // 5.1-5.6 : sur une note de 500 blocs, seuls les blocs proches de
                        // l'ecran instancient reellement leur `NSViewRepresentable`
                        // (`RichTextBlockView`), donc leur `NSTextView` TextKit 2 complet.
                        // Un bloc qui sort de la zone materialisee est DEMONTE
                        // (`RichTextBlockView.dismantleNSView`) puis RECREE (`makeNSView`)
                        // s'il revient -- voir la documentation de
                        // `RichTextEditingRepresentable.updateNSView` pour la consequence
                        // sur le focus AppKit et sa restauration, et celle de
                        // `scrollToFocusedBlockIfNeeded(_:proxy:)` pour la consequence sur la
                        // navigation clavier. Consequence ACCEPTEE, documentee, non
                        // corrigee ici : sans la hauteur reelle des blocs non materialises
                        // (variable, TextKit 2 ne la connait qu'une fois monte), la barre
                        // de defilement peut sauter legerement en remontant dans une tres
                        // longue note -- limitation connue de tout `LazyVStack` a hauteur
                        // de ligne variable, pas un defaut introduit par ce fichier.
                        // `ZStack(alignment: .topLeading)` plutot qu'un simple `LazyVStack`
                        // seul (Phase 6, sous-etape 6.4/6.5) : porte le menu "/" en
                        // SURIMPRESSION du contenu (voir `SlashMenuOverlay`), dans le MEME
                        // `coordinateSpace` nomme que `EditorController.blockFrames` (deplace
                        // ici depuis le `LazyVStack` -- voir plus bas) -- necessaire pour que
                        // `SlashMenuOverlay` ancre sa position aux memes coordonnees que
                        // celles deja publiees par `BlockFramePreferenceKey`, sans introduire
                        // une deuxieme cle de preference dediee.
                        ZStack(alignment: .topLeading) {
                            LazyVStack(alignment: .leading, spacing: SlateGeometry.editorBlockSpacing) {
                                let topLevelBlocks = BlockOrdering.topLevelBlocks(of: note)
                                // Calcule UNE SEULE FOIS par rendu complet (sous-etape 5.6, voir
                                // `EditorController.selectionRangePositions()`), enfile jusqu'a
                                // chaque `BlockTreeView` -- jamais recalcule bloc par bloc. Reste
                                // correct avec le `LazyVStack` : cette liste couvre TOUS les
                                // blocs de la note (materialises ou non), seul l'AFFICHAGE de
                                // l'aplat de plage est necessairement limite aux blocs
                                // effectivement rendus a l'ecran.
                                let rangePositions = editorController.selectionRangePositions()
                                ForEach(topLevelBlocks, id: \.id) { block in
                                    BlockTreeView(
                                        block: block,
                                        siblings: topLevelBlocks,
                                        indentLevel: 0,
                                        strings: strings,
                                        editorController: editorController,
                                        rangePositions: rangePositions
                                    )
                                    // Ancre requise par `ScrollViewReader.scrollTo(_:anchor:)`
                                    // ci-dessous : DISTINCTE de l'identite `ForEach(id: \.id)`
                                    // (qui pilote le diffing SwiftUI, pas le ciblage du
                                    // scroll-to).
                                    .id(block.id)
                                }
                            }

                            // Menu "/" (Phase 6) : uniquement si un menu est ouvert ET que le
                            // bloc qu'il vise est resolu (potentiellement imbrique -- item de
                            // liste -- donc pas necessairement dans `topLevelBlocks`, voir
                            // `slashMenuBlock`).
                            if let slashMenuBlock {
                                SlashMenuOverlay(block: slashMenuBlock, editorController: editorController)
                            }

                            // Selecteur "@"/"[[" (Phase 16), meme geometrie que le "/".
                            if let pageMentionBlock {
                                PageMentionOverlay(block: pageMentionBlock, editorController: editorController)
                            }

                            // Barre de formatage flottante (Phase 7) : meme
                            // `coordinateSpace` nommee, meme raison de separation
                            // overlay/popover que le menu "/" ci-dessus (voir
                            // `FormatBarOverlay`).
                            if let inlineSelection = editorController.inlineSelection, let formatBarBlock {
                                FormatBarOverlay(
                                    block: formatBarBlock,
                                    editorController: editorController,
                                    selection: inlineSelection
                                )
                            }

                            // Ligne d'insertion d'un glisser de FICHIERS (Phase 10,
                            // report Phase 9, artboard C de P2) : "meme ligne
                            // d'insertion que le deplacement de blocs" -- remplace,
                            // pendant ce type de glisser precis, la ligne generique de
                            // `BlockContainer.dropEdge` (voir `BlockTreeView.
                            // dropEdgeForContainer`) par `BlockDropIndicatorView`
                            // (`SlateUI`), seule a porter le badge de comptage a partir
                            // de 2 fichiers. Positionnee au bord du cadre DEJA mesure du
                            // bloc cible (`EditorController.blockFrames`), aucune
                            // nouvelle geometrie.
                            if let fileCount = editorController.dragFileCount,
                               let target = editorController.dragTarget,
                               let frame = editorController.blockFrames[target.blockID] {
                                BlockDropIndicatorView(fileCount: fileCount)
                                    .frame(maxWidth: .infinity)
                                    .position(
                                        x: frame.midX,
                                        y: target.edge == .bottom || target.edge == .trailing ? frame.maxY : frame.minY
                                    )
                                    .allowsHitTesting(false)
                            }
                        }
                        // Coordonnees partagees pour la resolution "quel bloc est sous le
                        // pointeur" pendant un glisser de selection (sous-etape 5.6, voir
                        // `BlockFramePreferenceKey`/`EditorController.blockFrames`), ET pour
                        // l'ancrage du menu "/" (voir ci-dessus).
                        .coordinateSpace(name: Self.blockListCoordinateSpace)
                        .onPreferenceChange(BlockFramePreferenceKey.self) { frames in
                            editorController.updateBlockFrames(frames)
                        }
                        // Point d'attache UNIQUE du glisser-depose de blocs ET de
                        // fichiers (Phase 10) -- voir la documentation de tete de
                        // `BlockAndFileDropDelegate` pour le choix du `DropDelegate`
                        // legacy plutot que `dropDestination(for:action:)`.
                        .onDrop(
                            of: BlockAndFileDropDelegate.acceptedTypes,
                            delegate: BlockAndFileDropDelegate(editorController: editorController)
                        )
                    }

                    // Backlinks (Phase 16), sous le contenu.
                    if !backlinkNotes.isEmpty {
                        BacklinksSectionView(notes: backlinkNotes, onSelect: onNavigateToNote)
                    }

                    NoteDocumentBottomSpacerView(onTap: editorController.appendTrailingParagraph)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(SlateColor.bgEditor)
            .onChange(of: editorController.focusedBlockID) { _, newValue in
                scrollToFocusedBlockIfNeeded(newValue, proxy: scrollProxy)
            }
            // Phase 14 : publie "Focus editeur" (⌃⌘3) pour `SlateAppCommands` -- voir
            // `EditorFocusedValues.swift`.
            .focusedSceneValue(\.editorFocusAction, editorFocusAction)
            // Backlinks (Phase 16) : voir la documentation de `backlinkNotes`.
            .task(id: note.id) {
                backlinkNotes = (try? PageLinkBacklinks.notes(linkingTo: note, in: modelContext)) ?? []
            }
        }
    }

    /// Voir `EditorFocusedValues.editorFocusAction`. `nil` si la note n'a aucun bloc de
    /// premier niveau (note toute juste creee sans paragraphe visible).
    private var editorFocusAction: (() -> Void)? {
        guard let firstBlock = BlockOrdering.topLevelBlocks(of: note).first else { return nil }
        return { editorController.selectBlock(firstBlock) }
    }

    /// Complement OBLIGATOIRE du `LazyVStack` ci-dessus (pas une simple amelioration) :
    /// sans lui, deplacer le focus vers un bloc SORTI de la zone materialisee (fleche
    /// haut/bas en bord de bloc, Entree en fin de note...) mettrait a jour
    /// `EditorController.focusedBlockID`/`pendingCaretRequest` SANS QUE RIEN NE LES
    /// CONSOMME -- `RichTextBlockView.updateNSView` (seul endroit qui consomme
    /// `pendingCaretRequest`, voir sa documentation) n'est jamais appele pour un bloc que
    /// le `LazyVStack` n'a pas encore instancie. La navigation clavier "s'arreterait"
    /// silencieusement au bord de l'ecran des que la note depasse une poignee d'ecrans,
    /// exactement la regression que `docs/05_editeur_blocs.md` interdit ("les fleches
    /// doivent continuer de traverser tout le document").
    ///
    /// `proxy.scrollTo(_:anchor:)` avec `anchor: nil` (jamais anime -- volontairement PAS
    /// enveloppe dans `withAnimation`, pour un saut instantane plutot qu'un defilement
    /// anime qui materialiserait/demonterait en rafale tous les blocs intermediaires) :
    /// - ne fait RIEN si `newValue` est deja visible (comportement documente de
    ///   `anchor: nil`) ;
    /// - sinon saute directement a son ancre `.id(block.id)`, ce qui force le
    ///   `LazyVStack` a materialiser ce bloc -- `RichTextBlockView.updateNSView` est alors
    ///   appele et consomme enfin `pendingCaretRequest`.
    private func scrollToFocusedBlockIfNeeded(_ blockID: UUID?, proxy: ScrollViewProxy) {
        guard let blockID else { return }
        proxy.scrollTo(blockID, anchor: nil)
    }

    /// `Block` vise par `EditorController.slashMenuState`, ou `nil` si aucun menu n'est
    /// ouvert (Phase 6). `BlockOrdering.flattenedBlocks(of:)`, jamais `topLevelBlocks`
    /// seul : le bloc peut etre imbrique (item de liste a puces/numerotee/tache).
    private var slashMenuBlock: Block? {
        guard let blockID = editorController.slashMenuState?.blockID else { return nil }
        return BlockOrdering.flattenedBlocks(of: note).first { $0.id == blockID }
    }

    /// Meme motif que `slashMenuBlock`, pour `EditorController.pageMentionState` (Phase 16).
    private var pageMentionBlock: Block? {
        guard let blockID = editorController.pageMentionState?.blockID else { return nil }
        return BlockOrdering.flattenedBlocks(of: note).first { $0.id == blockID }
    }

    /// `Block` vise par `EditorController.inlineSelection` (Phase 7), meme motif que
    /// `slashMenuBlock` ci-dessus.
    private var formatBarBlock: Block? {
        guard let blockID = editorController.inlineSelection?.blockID else { return nil }
        return BlockOrdering.flattenedBlocks(of: note).first { $0.id == blockID }
    }
}
