import Foundation
import SlateModel
import SwiftData
import Testing

@testable import SlateEditor

/// Commande "/" `databaseView` (Phase 17, `docs/17_base_de_donnees.md`) : insertion
/// d'un bloc `databaseView` EN DESSOUS (jamais en place, meme motif que `image`/`file`),
/// avec une `Database` inline fraichement creee et un premier champ Texte par defaut --
/// jamais une grille vide sans aucune colonne (voir `executeDatabaseCommand(in:)`).
@MainActor
@Suite("EditorController - commande / base de donnees")
struct EditorControllerDatabaseCommandTests {
    private struct Fixture {
        let controller: EditorController
        let note: Note
        let context: ModelContext
    }

    private func makeNote(text: String) throws -> Fixture {
        let container = try SlateContainer.make(inMemory: true)
        let context = ModelContext(container)
        let note = Note(title: "Test")
        context.insert(note)
        let block = Block(order: 0, type: .paragraph, text: RichText(plainText: text))
        block.note = note
        context.insert(block)
        note.blocks = [block]
        try context.save()

        let controller = EditorController(note: note, modelContext: context)
        return Fixture(controller: controller, note: note, context: context)
    }

    @Test("La commande / base de donnees insere un bloc databaseView en dessous avec une base inline prete a l'emploi")
    func slashDatabaseInsertsInlineDatabaseBelow() throws {
        let fixture = try makeNote(text: "/base de donnees")
        let block = try #require(BlockOrdering.topLevelBlocks(of: fixture.note).first)
        fixture.controller.updateSlashMenuState(for: block, plainText: "/", caretOffset: 1)
        fixture.controller.updateSlashMenuState(for: block, plainText: "/base de donnees", caretOffset: 16)
        #expect(fixture.controller.slashMenuState?.selectedCommandID == "databaseView")

        fixture.controller.handleSlashMenuReturn(in: block)
        try fixture.context.save()

        let blocks = BlockOrdering.topLevelBlocks(of: fixture.note)
        #expect(blocks.count == 3)
        #expect(blocks[1].type == .databaseView)
        #expect(blocks[2].type == .paragraph)
        #expect(fixture.controller.focusedBlockID == blocks[2].id)

        let database = try #require(blocks[1].databaseView)
        #expect(database.hostMode == .inline)
        #expect(database.hostBlock?.id == blocks[1].id)
        #expect(database.fields?.count == 1)
        #expect(database.fields?.first?.fieldType == .text)

        // Persistee reellement (pas seulement rattachee en memoire) : un vrai fetch
        // apres `save()` doit la retrouver, meme motif que `EditorControllerDeletionPurgeTests`.
        let fetchedDatabases = try fixture.context.fetch(FetchDescriptor<Database>())
        #expect(fetchedDatabases.contains { $0.id == database.id })
        let fetchedFields = try fixture.context.fetch(FetchDescriptor<DatabaseField>())
        #expect(fetchedFields.contains { $0.database?.id == database.id })
    }
}
