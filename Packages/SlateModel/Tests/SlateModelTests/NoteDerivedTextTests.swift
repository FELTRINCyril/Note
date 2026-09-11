import Foundation
import SwiftData
import Testing

@testable import SlateModel

/// Verifie `Note.refreshDerivedText()` : concatenation dans l'ordre des blocs texte,
/// filtrage des blocs sans texte (divider, image...), et troncature du snippet.
@MainActor
struct NoteDerivedTextTests {

    @Test
    func derivedTextConcatenatesOnlyTextBearingBlocksInOrder() {
        let note = Note(title: "Test")
        let heading = Block(order: 0, type: .heading1, text: RichText(plainText: "Titre"), note: note)
        let divider = Block(order: 1, type: .divider, note: note)
        let paragraph = Block(order: 2, type: .paragraph, text: RichText(plainText: "Contenu."), note: note)
        note.blocks = [paragraph, divider, heading] // insere volontairement dans le desordre

        note.refreshDerivedText()

        #expect(note.plainText == "Titre\nContenu.")
        #expect(note.snippetText == "Titre\nContenu.")
    }

    @Test
    func derivedTextIgnoresEmptyOrMissingText() {
        let note = Note(title: "Test")
        let emptyParagraph = Block(order: 0, type: .paragraph, text: RichText(plainText: ""), note: note)
        let image = Block(order: 1, type: .image, note: note)
        let realParagraph = Block(order: 2, type: .paragraph, text: RichText(plainText: "Seul texte."), note: note)
        note.blocks = [emptyParagraph, image, realParagraph]

        note.refreshDerivedText()

        #expect(note.plainText == "Seul texte.")
    }

    @Test
    func snippetIsTruncatedButPlainTextIsNot() {
        let note = Note(title: "Test")
        let longText = String(repeating: "a", count: 500)
        note.blocks = [Block(order: 0, type: .paragraph, text: RichText(plainText: longText), note: note)]

        note.refreshDerivedText()

        #expect(note.plainText.count == 500)
        #expect(note.snippetText.count == 160)
    }

    @Test
    func derivedTextIsEmptyForNoteWithoutBlocks() {
        let note = Note(title: "Vide")
        note.refreshDerivedText()

        #expect(note.plainText.isEmpty)
        #expect(note.snippetText.isEmpty)
    }

    /// Verrouille la recursion de `collectText` (revue de Phase 8) : avant cette revue,
    /// `refreshDerivedText()` ne descendait PAS dans `children`, donc le texte d'un
    /// sous-item de liste (ou de tout bloc imbrique) n'entrait jamais dans `plainText`/
    /// `snippetText` -- un bug preexistant qui touchait la recherche plein texte (Phase
    /// 15) et l'extrait de la liste de notes DES la Phase 5 (items de liste imbriques),
    /// pas seulement les tableaux de la Phase 8.
    @Test
    func derivedTextDescendsIntoNestedChildrenInOrder() {
        let note = Note(title: "Test")
        let rootItem = Block(order: 0, type: .bulletedList, text: RichText(plainText: "Item racine"), note: note)
        let nestedItem = Block(
            order: 0, type: .bulletedList, text: RichText(plainText: "Sous-item"), note: note, parent: rootItem
        )
        let doublyNestedItem = Block(
            order: 0, type: .bulletedList, text: RichText(plainText: "Sous-sous-item"),
            note: note, parent: nestedItem
        )
        nestedItem.children = [doublyNestedItem]
        rootItem.children = [nestedItem]
        let trailingParagraph = Block(
            order: 1, type: .paragraph, text: RichText(plainText: "Paragraphe suivant"), note: note
        )
        note.blocks = [rootItem, trailingParagraph]

        note.refreshDerivedText()

        #expect(note.plainText == "Item racine\nSous-item\nSous-sous-item\nParagraphe suivant")
    }

    /// Un bloc SANS texte propre (`divider`, `table`...) mais avec des enfants porteurs
    /// de texte doit quand meme laisser remonter le texte de ses enfants -- c'est
    /// exactement ce qui permet au contenu d'un tableau (`tableRow`/`tableCell`, aucun
    /// des deux n'etant lui-meme dans `textBearingTypes` sauf `tableCell`) de contribuer
    /// a `plainText` alors que le `table` racine n'a pas de `RichText` propre. Verrouille
    /// le meme mecanisme avec un type non textuel plus simple (`divider`) pour isoler la
    /// recursion elle-meme de la logique specifique aux tableaux (deja couverte par
    /// `BlockTableStructureTests`).
    @Test
    func derivedTextDescendsThroughANonTextBearingParent() {
        let note = Note(title: "Test")
        let divider = Block(order: 0, type: .divider, note: note)
        let childUnderDivider = Block(
            order: 0, type: .paragraph, text: RichText(plainText: "Enfant d'un separateur"),
            note: note, parent: divider
        )
        divider.children = [childUnderDivider]
        note.blocks = [divider]

        note.refreshDerivedText()

        #expect(note.plainText == "Enfant d'un separateur")
    }
}
