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
}
