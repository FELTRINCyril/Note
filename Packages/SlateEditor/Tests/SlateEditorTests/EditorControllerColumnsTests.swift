import Foundation
import SlateModel
import SwiftData
import Testing

@testable import SlateEditor

/// `EditorController+Columns.swift` : creation de colonnes par depot lateral, ajout
/// d'une colonne, redimensionnement, et surtout la PURGE reelle du `ModelContext` a la
/// dissolution -- meme motif que `EditorControllerDeletionPurgeTests` (Phase 8/10) : un
/// test qui se contenterait de verifier `note.blocks`/`children` ne verrait RIEN d'une
/// regression de purge, puisque `ColumnStructure` (logique pure) ne fait que DETACHER,
/// jamais supprimer du store.
@MainActor
@Suite("EditorController - colonnes (Phase 10)")
struct EditorControllerColumnsTests {
    private struct Fixture {
        let controller: EditorController
        let note: Note
        let context: ModelContext
    }

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

    @Test("createColumns(moving:onto:edge:) construit la structure et persiste")
    func createColumnsBuildsStructureAndPersists() throws {
        let fixture = try makeNote(paragraphs: 2)
        let blocks = BlockOrdering.topLevelBlocks(of: fixture.note)

        fixture.controller.createColumns(moving: blocks[1], onto: blocks[0], edge: .trailing)
        try fixture.context.save()

        let topLevel = BlockOrdering.topLevelBlocks(of: fixture.note)
        #expect(topLevel.count == 1)
        #expect(topLevel.first?.type == .columnList)
        let columns = BlockOrdering.children(of: topLevel[0])
        #expect(columns.count == 2)
    }

    @Test("createColumns refuse un tableau (une colonne accepte tout sauf un tableau)")
    func createColumnsRejectsTable() throws {
        let fixture = try makeNote(paragraphs: 1)
        let paragraph = try #require(BlockOrdering.topLevelBlocks(of: fixture.note).first)
        let table = Block.makeTable(rows: 2, columns: 2, order: 1, note: fixture.note)
        fixture.context.insert(table)
        for row in table.children ?? [] {
            fixture.context.insert(row)
            for cell in row.children ?? [] { fixture.context.insert(cell) }
        }
        fixture.note.blocks = (fixture.note.blocks ?? []) + [table]
        try fixture.context.save()

        fixture.controller.createColumns(moving: table, onto: paragraph, edge: .trailing)

        let topLevel = BlockOrdering.topLevelBlocks(of: fixture.note)
        #expect(!topLevel.contains { $0.type == .columnList })
    }

    @Test("dissolveIfEmptied purge du ModelContext les blocs de structure orphelins")
    func dissolveIfEmptiedPurgesStructuralBlocksFromContext() throws {
        let fixture = try makeNote(paragraphs: 3)
        let blocks = BlockOrdering.topLevelBlocks(of: fixture.note)
        fixture.controller.createColumns(moving: blocks[1], onto: blocks[0], edge: .trailing)
        try fixture.context.save()

        let columnList = try #require(BlockOrdering.topLevelBlocks(of: fixture.note).first { $0.type == .columnList })
        let columns = BlockOrdering.children(of: columnList)
        let secondColumn = columns[1]
        let movedContent = try #require(BlockOrdering.children(of: secondColumn).first)
        let columnListID = columnList.id
        let secondColumnID = secondColumn.id

        // Simule un deplacement REEL du contenu de la seconde colonne vers l'exterieur
        // (comme le ferait un futur drag & drop), puis le nettoyage de la structure.
        BlockOrdering.detachPreservingChildren(movedContent)
        BlockOrdering.insert(movedContent, after: blocks[2])
        fixture.controller.dissolveIfEmptied(columnList)
        try fixture.context.save()

        let remaining = try fixture.context.fetch(FetchDescriptor<Block>())
        #expect(!remaining.contains { $0.id == columnListID })
        #expect(!remaining.contains { $0.id == secondColumnID })
        #expect(remaining.contains { $0.id == movedContent.id })
    }

    @Test("setColumnFractions persiste les nouvelles largeurs")
    func setColumnFractionsPersistsWidths() throws {
        let fixture = try makeNote(paragraphs: 2)
        let blocks = BlockOrdering.topLevelBlocks(of: fixture.note)
        fixture.controller.createColumns(moving: blocks[1], onto: blocks[0], edge: .trailing)
        try fixture.context.save()
        let columnList = try #require(BlockOrdering.topLevelBlocks(of: fixture.note).first { $0.type == .columnList })

        fixture.controller.setColumnFractions([1, 3], in: columnList)

        let columns = BlockOrdering.children(of: columnList)
        #expect(abs((columns[0].attributes.columnWidthRatio ?? 0) - 0.25) < 0.0001)
        #expect(abs((columns[1].attributes.columnWidthRatio ?? 0) - 0.75) < 0.0001)
    }
}
