import Foundation
import SlateModel
import Testing

@testable import SlateEditor

/// `EditorController+SpecialBlocks.swift` : actions ponctuelles sur les blocs speciaux.
/// Construit des `Note`/`Block` en memoire, sans `ModelContext` (comme
/// `EditorControllerTests`) -- `modelContext` reste `nil`, `persistStructuralChange()`
/// ne fait donc rien de plus que muter le graphe deja verifie ici.
@MainActor
@Suite("EditorController.SpecialBlocks")
struct EditorControllerSpecialBlocksTests {
    @Test("setCalloutVariant(_:in:) ecrit BlockAttributes.calloutVariant")
    func setCalloutVariantWritesAttribute() {
        let note = Note(title: "Test")
        let callout = Block(order: 0, type: .callout, text: RichText(plainText: "Texte"), note: note)
        note.blocks = [callout]
        let controller = EditorController(note: note)

        controller.setCalloutVariant("warning", in: callout)

        #expect(callout.attributes.calloutVariant == "warning")
    }

    @Test("setCalloutVariant(nil, in:) revient a la variante neutre")
    func setCalloutVariantNilResetsToNeutral() {
        let note = Note(title: "Test")
        let callout = Block(order: 0, type: .callout, note: note)
        callout.attributes.calloutVariant = "success"
        note.blocks = [callout]
        let controller = EditorController(note: note)

        controller.setCalloutVariant(nil, in: callout)

        #expect(callout.attributes.calloutVariant == nil)
    }

    @Test("setCalloutVariant(_:in:) est sans effet sur un bloc qui n'est pas un callout")
    func setCalloutVariantNoOpOnNonCallout() {
        let note = Note(title: "Test")
        let paragraph = Block(order: 0, type: .paragraph, note: note)
        note.blocks = [paragraph]
        let controller = EditorController(note: note)

        controller.setCalloutVariant("warning", in: paragraph)

        #expect(paragraph.attributes.calloutVariant == nil)
    }
}
