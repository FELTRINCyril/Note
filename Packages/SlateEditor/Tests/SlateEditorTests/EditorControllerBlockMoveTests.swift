import Foundation
import SlateModel
import Testing

@testable import SlateEditor

/// Equivalent clavier obligatoire (Ctrl+Cmd+fleche haut/bas, Phase 10) du glisser de
/// reordonnancement : `EditorController+BlockMove.swift`. Verifie la delegation aux
/// primitives deja testees (`BlockOperationsTests`/`BlockSelectionOperationsTests`) et
/// qu'une annonce NON VIDE est produite exactement quand le deplacement a reellement eu
/// lieu -- le TEXTE localise resolu lui-meme n'est pas verifiable ici : `swift test`
/// (hors Xcode) ne compile pas `Localizable.xcstrings`, `String(localized:bundle:)`
/// retombe donc sur la CLE brute plutot que la phrase francaise/anglaise (limitation de
/// cet environnement de test, deja implicite dans le reste de ce module -- aucun test
/// existant n'affirme le CONTENU resolu d'une chaine localisee, seulement des proprietes
/// structurelles comme "non vide" ou "different du rawValue brut").
@MainActor
@Suite("EditorController - deplacement clavier avec annonce (Phase 10)")
struct EditorControllerBlockMoveTests {
    @Test("moveBlockDownWithAnnouncement deplace le bloc et produit une annonce")
    func moveBlockDownAnnouncesNewPosition() {
        let note = Note(title: "Test")
        let first = Block(order: 0, type: .paragraph, text: RichText(plainText: "Un"), note: note)
        let second = Block(order: 1, type: .paragraph, text: RichText(plainText: "Deux"), note: note)
        let third = Block(order: 2, type: .paragraph, text: RichText(plainText: "Trois"), note: note)
        note.blocks = [first, second, third]
        let controller = EditorController(note: note)

        let announcement = controller.moveBlockDownWithAnnouncement(first)

        #expect(announcement?.isEmpty == false)
        let blocks = BlockOrdering.topLevelBlocks(of: note)
        #expect(blocks.map { $0.text?.plainText } == ["Deux", "Un", "Trois"])
    }

    @Test("moveBlockUpWithAnnouncement retourne nil sans effet en tete de fratrie")
    func moveBlockUpAtTopReturnsNil() {
        let note = Note(title: "Test")
        let first = Block(order: 0, type: .paragraph, text: RichText(plainText: "Un"), note: note)
        let second = Block(order: 1, type: .paragraph, text: RichText(plainText: "Deux"), note: note)
        note.blocks = [first, second]
        let controller = EditorController(note: note)

        let announcement = controller.moveBlockUpWithAnnouncement(first)

        #expect(announcement == nil)
        #expect(BlockOrdering.topLevelBlocks(of: note).map { $0.text?.plainText } == ["Un", "Deux"])
    }

    @Test("moveSelectionRangeUpWithAnnouncement deplace tout le groupe et produit une annonce")
    func moveSelectionRangeUpAnnouncesFirstBlockPosition() {
        let note = Note(title: "Test")
        let first = Block(order: 0, type: .paragraph, text: RichText(plainText: "Un"), note: note)
        let second = Block(order: 1, type: .paragraph, text: RichText(plainText: "Deux"), note: note)
        let third = Block(order: 2, type: .paragraph, text: RichText(plainText: "Trois"), note: note)
        note.blocks = [first, second, third]
        let controller = EditorController(note: note)
        controller.selectBlock(second)
        controller.extendSelection(to: third)

        let announcement = controller.moveSelectionRangeUpWithAnnouncement()

        #expect(announcement?.isEmpty == false)
        let blocks = BlockOrdering.topLevelBlocks(of: note)
        #expect(blocks.map { $0.text?.plainText } == ["Deux", "Trois", "Un"])
    }

    @Test("moveSelectionRangeDownWithAnnouncement retourne nil sans plage active")
    func moveSelectionRangeDownWithoutSelectionReturnsNil() {
        let note = Note(title: "Test")
        let first = Block(order: 0, type: .paragraph, text: RichText(plainText: "Un"), note: note)
        note.blocks = [first]
        let controller = EditorController(note: note)

        #expect(controller.moveSelectionRangeDownWithAnnouncement() == nil)
    }
}
