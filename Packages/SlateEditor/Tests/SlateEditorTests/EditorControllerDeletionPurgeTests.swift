import Foundation
import SlateModel
import SwiftData
import Testing

@testable import SlateEditor

/// Purge reelle du `ModelContext` a la suppression d'un bloc ORDINAIRE (non-tableau),
/// par le menu de bloc et par la suppression multi-blocs.
///
/// La revue de phase 8 a trouve le cas du tableau (voir `EditorControllerTableTests`) :
/// `BlockOperations` ne fait que DETACHER un bloc du graphe en memoire, sans jamais le
/// supprimer du store. La meme lacune valait pour tous les autres types de bloc depuis
/// la phase 5. Consequence invisible dans l'interface mais bien reelle : chaque bloc
/// supprime restait indefiniment persiste, et serait synchronise vers CloudKit.
///
/// Ces tests passent par un vrai `ModelContainer` en memoire : un test qui se
/// contenterait de verifier `note.blocks` ne verrait RIEN du probleme, puisque le
/// detachement, lui, fonctionnait deja correctement.
@MainActor
@Suite("EditorController - purge du store a la suppression")
struct EditorControllerDeletionPurgeTests {
    private struct Fixture {
        let controller: EditorController
        let note: Note
        let context: ModelContext
    }

    /// Note de `count` paragraphes racine, tous inseres dans un contexte reel.
    private func makeNote(paragraphs count: Int) throws -> Fixture {
        let container = try SlateContainer.make(inMemory: true)
        let context = ModelContext(container)
        let note = Note(title: "Test")
        context.insert(note)
        var blocks: [Block] = []
        for index in 0..<count {
            let block = Block(order: index, type: .paragraph, text: RichText(plainText: "Bloc \(index)"))
            block.note = note
            context.insert(block)
            blocks.append(block)
        }
        note.blocks = blocks
        try context.save()

        let controller = EditorController(note: note, modelContext: context)
        return Fixture(controller: controller, note: note, context: context)
    }

    @Test("Supprimer un paragraphe le retire vraiment du store, pas seulement du document")
    func deleteBlockPurgesOrdinaryBlockFromContext() throws {
        let fixture = try makeNote(paragraphs: 3)
        let target = try #require(BlockOrdering.topLevelBlocks(of: fixture.note).first)
        let targetID = target.id

        fixture.controller.deleteBlock(target)
        try fixture.context.save()

        let remaining = try fixture.context.fetch(FetchDescriptor<Block>())
        #expect(remaining.count == 2)
        #expect(!remaining.contains { $0.id == targetID })
    }

    @Test("Supprimer une plage de plusieurs blocs les retire tous du store")
    func deleteSelectionRangePurgesEveryBlockFromContext() throws {
        let fixture = try makeNote(paragraphs: 4)
        let blocks = BlockOrdering.topLevelBlocks(of: fixture.note)
        let deletedIDs = [blocks[0].id, blocks[1].id, blocks[2].id]
        fixture.controller.blockSelectionRange = BlockSelectionRange(
            anchorBlockID: blocks[0].id,
            focusBlockID: blocks[2].id
        )

        fixture.controller.deleteSelectionRange()
        try fixture.context.save()

        let remaining = try fixture.context.fetch(FetchDescriptor<Block>())
        #expect(remaining.count == 1)
        #expect(remaining.first?.id == blocks[3].id)
        for id in deletedIDs {
            #expect(!remaining.contains { $0.id == id })
        }
    }

    @Test("Les enfants promus survivent a la suppression de leur parent")
    func promotedChildrenSurviveParentDeletion() throws {
        // `BlockOrdering.remove(_:)` PROMEUT les enfants directs a la place du bloc
        // supprime : la cascade `Block.children` ne doit donc pas les emporter, sinon
        // supprimer un item de liste detruirait silencieusement ses sous-items.
        let fixture = try makeNote(paragraphs: 1)
        let parent = try #require(BlockOrdering.topLevelBlocks(of: fixture.note).first)
        let child = Block(order: 0, type: .bulletedList, text: RichText(plainText: "Sous-item"))
        child.note = fixture.note
        child.parent = parent
        fixture.context.insert(child)
        try fixture.context.save()
        let childID = child.id

        fixture.controller.deleteBlock(parent)
        try fixture.context.save()

        let remaining = try fixture.context.fetch(FetchDescriptor<Block>())
        #expect(remaining.contains { $0.id == childID })
        #expect(!remaining.contains { $0.id == parent.id })
    }
}
