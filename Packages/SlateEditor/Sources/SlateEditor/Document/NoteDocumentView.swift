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

        return ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                NoteHeaderView(
                    note: note,
                    metadataLine: metadataLine,
                    strings: strings,
                    onAddIcon: onAddIcon,
                    onAddCover: onAddCover
                )

                EditorContentColumn {
                    VStack(alignment: .leading, spacing: SlateGeometry.editorBlockSpacing) {
                        let topLevelBlocks = BlockOrdering.topLevelBlocks(of: note)
                        // Calcule UNE SEULE FOIS par rendu complet (sous-etape 5.6, voir
                        // `EditorController.selectionRangePositions()`), enfile jusqu'a
                        // chaque `BlockTreeView` -- jamais recalcule bloc par bloc.
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
                        }
                    }
                    // Coordonnees partagees pour la resolution "quel bloc est sous le
                    // pointeur" pendant un glisser de selection (sous-etape 5.6, voir
                    // `BlockFramePreferenceKey`/`EditorController.blockFrames`).
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
