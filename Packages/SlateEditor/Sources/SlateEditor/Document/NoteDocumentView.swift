import SlateModel
import SlateUI
import SwiftUI

/// Rendu complet d'une note : en-tete (`NoteHeaderView`) + corps de blocs, tries par
/// `order` et imbriques selon `parent`/`children` (`BlockOrdering`), en LECTURE SEULE
/// (Phase 5.1). Seul le titre est editable, voir `NoteHeaderView`.
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
    private let note: Note
    private let metadataLine: String
    private let strings: NoteEditorStrings
    private let onAddIcon: () -> Void
    private let onAddCover: () -> Void

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
    }

    public var body: some View {
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
                    VStack(alignment: .leading, spacing: SlateGeometry.editorBlockSpacing) {
                        let topLevelBlocks = BlockOrdering.topLevelBlocks(of: note)
                        ForEach(topLevelBlocks, id: \.id) { block in
                            BlockTreeView(block: block, siblings: topLevelBlocks, indentLevel: 0, strings: strings)
                        }
                    }
                }

                NoteDocumentBottomSpacerView()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(SlateColor.bgEditor)
    }
}

#Preview("NoteDocumentView - clair") {
    NoteDocumentView(note: .previewSample, metadataLine: "Modifiee aujourd'hui a 14:22 - 6 mots")
        .frame(width: 900, height: 700)
        .environment(\.colorScheme, .light)
}

#Preview("NoteDocumentView - sombre") {
    NoteDocumentView(note: .previewSample, metadataLine: "Modifiee aujourd'hui a 14:22 - 6 mots")
        .frame(width: 900, height: 700)
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
