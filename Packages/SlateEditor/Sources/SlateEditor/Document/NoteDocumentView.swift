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
        onAddCover: @escaping () -> Void = {}
    ) {
        self.note = note
        self.metadataLine = metadataLine
        self.strings = strings
        self.onAddIcon = onAddIcon
        self.onAddCover = onAddCover
        self._editorController = State(initialValue: EditorController(note: note))
    }

    public var body: some View {
        // Le `ModelContext` reel n'est disponible que via `@Environment`, jamais a
        // l'`init` (voir `EditorController.updateModelContext`) : idempotent, sans
        // effet observable si la valeur n'a pas change.
        editorController.updateModelContext(modelContext)

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
                        }
                        // Coordonnees partagees pour la resolution "quel bloc est sous le
                        // pointeur" pendant un glisser de selection (sous-etape 5.6, voir
                        // `BlockFramePreferenceKey`/`EditorController.blockFrames`), ET pour
                        // l'ancrage du menu "/" (voir ci-dessus).
                        .coordinateSpace(name: Self.blockListCoordinateSpace)
                        .onPreferenceChange(BlockFramePreferenceKey.self) { frames in
                            editorController.updateBlockFrames(frames)
                        }
                    }

                    NoteDocumentBottomSpacerView(onTap: editorController.appendTrailingParagraph)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(SlateColor.bgEditor)
            .onChange(of: editorController.focusedBlockID) { _, newValue in
                scrollToFocusedBlockIfNeeded(newValue, proxy: scrollProxy)
            }
        }
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
}

/// Conteneur SwiftData en memoire pour les previews : `RichTextBlockView` (Phase 5.2)
/// lit `@Environment(\.modelContext)`, contrairement aux previews en lecture seule de
/// la Phase 5.1. Pas de `try!` (CLAUDE.md §5) : repli sur un texte de diagnostic si la
/// creation echoue, plutot qu'un crash de preview.
private struct NoteDocumentPreviewHost: View {
    var body: some View {
        Group {
            if let container = try? SlateContainer.make(inMemory: true) {
                NoteDocumentView(note: .previewSample, metadataLine: "Modifiee aujourd'hui a 14:22 - 6 mots")
                    .modelContainer(container)
            } else {
                Text("Conteneur SwiftData indisponible pour cette preview")
            }
        }
        .frame(width: 900, height: 700)
    }
}

#Preview("NoteDocumentView - clair") {
    NoteDocumentPreviewHost()
        .environment(\.colorScheme, .light)
}

#Preview("NoteDocumentView - sombre") {
    NoteDocumentPreviewHost()
        .environment(\.colorScheme, .dark)
}

/// Plage de selection multi-blocs (sous-etape 5.6) : trois blocs consecutifs
/// selectionnes via `EditorController.selectBlock(_:)`/`extendSelection(to:)` -- exige
/// par la tache ("Preview a jour montrant une plage selectionnee de trois blocs").
/// Contourne `NoteDocumentView` (qui construit toujours son PROPRE `EditorController`,
/// non injectable depuis l'exterieur) pour rendre directement `BlockTreeView` avec un
/// controleur PRE-configure, sur le meme schema (`EditorContentColumn`, `VStack`,
/// `ForEach`) que le corps de `NoteDocumentView`.
private struct NoteDocumentSelectionRangePreviewHost: View {
    var body: some View {
        Group {
            if let container = try? SlateContainer.make(inMemory: true) {
                content.modelContainer(container)
            } else {
                Text("Conteneur SwiftData indisponible pour cette preview")
            }
        }
        .frame(width: 900, height: 500)
        .background(SlateColor.bgEditor)
    }

    private var content: some View {
        let note = Note(title: "Feuille de route Q3")
        let first = Block(order: 0, type: .heading2, text: RichText(plainText: "Chantiers Q3"), note: note)
        let second = Block(
            order: 1, type: .paragraph, text: RichText(plainText: "Edition, sync, verrouillage."), note: note
        )
        let third = Block(order: 2, type: .quote, text: RichText(plainText: "Le premier passe devant."), note: note)
        let fourth = Block(order: 3, type: .paragraph, text: RichText(plainText: "Reste hors de la plage."), note: note)
        note.blocks = [first, second, third, fourth]
        note.refreshDerivedText()

        let editorController = EditorController(note: note)
        editorController.selectBlock(first)
        editorController.extendSelection(to: third)
        let rangePositions = editorController.selectionRangePositions()

        return ScrollView {
            EditorContentColumn {
                VStack(alignment: .leading, spacing: SlateGeometry.editorBlockSpacing) {
                    let topLevelBlocks = BlockOrdering.topLevelBlocks(of: note)
                    ForEach(topLevelBlocks, id: \.id) { block in
                        BlockTreeView(
                            block: block,
                            siblings: topLevelBlocks,
                            indentLevel: 0,
                            strings: NoteEditorStrings(),
                            editorController: editorController,
                            rangePositions: rangePositions
                        )
                    }
                }
            }
            .padding(.vertical, Spacing.lg)
        }
    }
}

#Preview("NoteDocumentView - plage de 3 blocs selectionnes, clair") {
    NoteDocumentSelectionRangePreviewHost()
        .environment(\.colorScheme, .light)
}

#Preview("NoteDocumentView - plage de 3 blocs selectionnes, sombre") {
    NoteDocumentSelectionRangePreviewHost()
        .environment(\.colorScheme, .dark)
}

extension Note {
    /// Note d'exemple pour les previews de ce module : un panorama des types de bloc
    /// livres en 5.1 (paragraphe, titre, liste imbriquee, citation, code, bloc non pris
    /// en charge) pour reperer visuellement une regression au premier coup d'oeil.
    fileprivate static var previewSample: Note {
        let note = Note(title: "Feuille de route Q3")
        let heading = Block(order: 0, type: .heading1, text: RichText(plainText: "Feuille de route"), note: note)
        let paragraph = Block(order: 1, type: .paragraph, text: RichText(plainText: "Un bloc = un noeud."), note: note)
        let bullet1 = Block(order: 2, type: .bulletedList, text: RichText(plainText: "Item racine"), note: note)
        let nested = Block(
            order: 0, type: .bulletedList, text: RichText(plainText: "Item imbrique"), note: note, parent: bullet1
        )
        let quote = Block(order: 3, type: .quote, text: RichText(plainText: "Une citation."), note: note)
        let code = Block(order: 4, type: .code, text: RichText(plainText: "let x = 1"), note: note)
        let unsupported = Block(order: 5, type: .table, note: note)
        bullet1.children = [nested]
        note.blocks = [heading, paragraph, bullet1, quote, code, unsupported]
        note.refreshDerivedText()
        return note
    }
}
