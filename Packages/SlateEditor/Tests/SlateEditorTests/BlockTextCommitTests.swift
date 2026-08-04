import Foundation
import SlateModel
import Testing

@testable import SlateEditor

/// `BlockTextCommit.flush(block:now:)` : le point de sauvegarde UNIQUE que
/// `RichTextBlockView` invoque au flush du debounce, jamais a chaque frappe. Isole
/// d'AppKit et de `ModelContext` (voir sa documentation) : ces tests construisent des
/// `Note`/`Block` en memoire, sans conteneur SwiftData.
@MainActor
@Suite("BlockTextCommit")
struct BlockTextCommitTests {
    @Test("flush() met a jour Note.modifiedAt avec l'horodatage fourni")
    func flushUpdatesModifiedAt() {
        let note = Note(title: "Test", modifiedAt: .distantPast)
        let block = Block(order: 0, type: .paragraph, text: RichText(plainText: "Bonjour"), note: note)
        note.blocks = [block]
        let now = Date(timeIntervalSince1970: 1_700_000_000)

        BlockTextCommit.flush(block: block, now: now)

        #expect(note.modifiedAt == now)
    }

    @Test("flush() recalcule plainText/snippetText via refreshDerivedText()")
    func flushRecomputesDerivedText() {
        let note = Note(title: "Test")
        let block = Block(order: 0, type: .paragraph, text: RichText(plainText: "Avant"), note: note)
        note.blocks = [block]
        note.refreshDerivedText()
        #expect(note.plainText == "Avant")

        // Simule ce que fait `RichTextBlockView.Coordinator.textDidChange` a chaque
        // frappe : ecrire `block.text` de facon synchrone, AVANT le flush debounce.
        block.text = RichText(plainText: "Apres edition")

        BlockTextCommit.flush(block: block)

        #expect(note.plainText == "Apres edition")
        #expect(note.snippetText == "Apres edition")
    }

    @Test("flush() sur un bloc sans note ne plante pas (bloc orphelin)")
    func flushOnOrphanBlockIsNoOp() {
        let block = Block(order: 0, type: .paragraph, text: RichText(plainText: "Orphelin"))

        // Ne doit ni planter ni lever : c'est le seul comportement observable a
        // verifier, `block.note` etant `nil`.
        BlockTextCommit.flush(block: block)
    }

    @Test("flush() ne touche pas Note.modifiedAt d'une AUTRE note")
    func flushOnlyAffectsOwnNote() {
        let editedNote = Note(title: "Editee", modifiedAt: .distantPast)
        let otherNote = Note(title: "Autre", modifiedAt: .distantPast)
        let block = Block(order: 0, type: .paragraph, text: RichText(plainText: "Contenu"), note: editedNote)
        editedNote.blocks = [block]
        let now = Date(timeIntervalSince1970: 1_700_000_000)

        BlockTextCommit.flush(block: block, now: now)

        #expect(editedNote.modifiedAt == now)
        #expect(otherNote.modifiedAt == .distantPast)
    }

    @Test("flush(note:) fonctionne meme si aucun bloc n'est plus attache a la note (bloc detache par une fusion)")
    func flushOnNoteWorksAfterBlockDetached() {
        let note = Note(title: "Test", modifiedAt: .distantPast)
        let block = Block(order: 0, type: .paragraph, text: RichText(plainText: "Contenu"), note: note)
        note.blocks = [block]
        let now = Date(timeIntervalSince1970: 1_700_000_000)

        // Simule ce que fait `BlockOrdering.remove(_:)` (sous-etape 5.3) : detacher un
        // bloc de sa note avant le flush -- `flush(block:)` deviendrait un no-op sur ce
        // bloc, `flush(note:)` reste le point d'entree correct pour l'`EditorController`.
        note.blocks = []
        block.note = nil

        BlockTextCommit.flush(note: note, now: now)

        #expect(note.modifiedAt == now)
        #expect(note.plainText.isEmpty)
    }
}
