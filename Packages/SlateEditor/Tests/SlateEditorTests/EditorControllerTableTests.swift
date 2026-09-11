import Foundation
import SlateModel
import SwiftData
import Testing

@testable import SlateEditor

/// `EditorController+Table.swift` : insertion/suppression de ligne/colonne AVEC
/// suppression effective des blocs retires du `ModelContext` (docs/08_blocs_speciaux.md,
/// "Tableaux"), et refus de la derniere ligne/colonne dissous en suppression du tableau
/// entier. Utilise un vrai `ModelContainer` en memoire (meme motif que
/// `BlockTableStructureTests.tableAndItsAttributesRoundTripThroughRealFetch`, cote
/// `SlateModel`) : la seule preuve honnete qu'un bloc retire ne reste pas orphelin.
@MainActor
@Suite("EditorController.Table")
struct EditorControllerTableTests {
    private func makeContext() throws -> ModelContext {
        let container = try SlateContainer.make(inMemory: true)
        return ModelContext(container)
    }

    private func insertRecursively(_ block: Block, into context: ModelContext) {
        context.insert(block)
        for child in block.children ?? [] {
            insertRecursively(child, into: context)
        }
    }

    /// Groupe les trois objets requis par chaque test (`large_tuple`, `.swiftlint.yml` :
    /// pas de tuple a 3 membres).
    private struct Fixture {
        let controller: EditorController
        let table: Block
        let context: ModelContext
    }

    private func makeControllerWithTable(rows: Int, columns: Int) throws -> Fixture {
        let context = try makeContext()
        let note = Note(title: "Test")
        let table = Block.makeTable(rows: rows, columns: columns, note: note)
        note.blocks = [table]
        context.insert(note)
        insertRecursively(table, into: context)
        try context.save()

        let controller = EditorController(note: note, modelContext: context)
        return Fixture(controller: controller, table: table, context: context)
    }

    // MARK: - Lignes

    @Test("insertTableRow(in:at:) ajoute une ligne, persistee")
    func insertRowAddsRow() throws {
        let fixture = try makeControllerWithTable(rows: 2, columns: 2)
        let controller = fixture.controller
        let table = fixture.table

        controller.insertTableRow(in: table)

        #expect(table.tableRows.count == 3)
        #expect(table.isTableRectangular)
    }

    @Test("removeTableRow(_:at:) retire la ligne ET supprime effectivement ses cellules du ModelContext")
    func removeRowDeletesFromContext() throws {
        let fixture = try makeControllerWithTable(rows: 3, columns: 2)
        let controller = fixture.controller
        let table = fixture.table
        let context = fixture.context
        let countBefore = try context.fetch(FetchDescriptor<Block>()).count

        controller.removeTableRow(table, at: 1)

        #expect(table.tableRows.count == 2)
        try context.save()
        let countAfter = try context.fetch(FetchDescriptor<Block>()).count
        // La ligne retiree (1 `tableRow` + 2 `tableCell`) a bien disparu du store, pas
        // seulement du graphe en memoire -- voir la documentation de tete de fichier.
        #expect(countAfter == countBefore - 3)
    }

    @Test("removeTableRow(_:at:) sur la DERNIERE ligne supprime le tableau entier (dissolution)")
    func removeLastRowDissolvesTable() throws {
        let fixture = try makeControllerWithTable(rows: 1, columns: 2)
        let controller = fixture.controller
        let table = fixture.table
        let context = fixture.context
        let note = table.note

        controller.removeTableRow(table, at: 0)
        try context.save()

        let remaining = try context.fetch(FetchDescriptor<Block>())
        // Le tableau entier (1 table + 1 row + 2 cells) a disparu ; un paragraphe de
        // secours a pris sa place (voir `BlockOperations.removeSubtree(_:from:)` puis le
        // filet de non-vacuite de `deleteBlock(_:)`).
        #expect(!remaining.contains { $0.id == table.id })
        #expect(note?.blocks?.count == 1)
        #expect(note?.blocks?.first?.type == .paragraph)
    }

    // MARK: - Colonnes

    @Test("insertTableColumn(in:at:) ajoute une cellule a CHAQUE ligne")
    func insertColumnAddsCellToEveryRow() throws {
        let fixture = try makeControllerWithTable(rows: 3, columns: 2)
        let controller = fixture.controller
        let table = fixture.table

        controller.insertTableColumn(in: table)

        #expect(table.isTableRectangular)
        #expect(table.tableColumnCount == 3)
    }

    @Test("removeTableColumn(_:at:) retire la colonne ET supprime effectivement les cellules du ModelContext")
    func removeColumnDeletesFromContext() throws {
        let fixture = try makeControllerWithTable(rows: 2, columns: 3)
        let controller = fixture.controller
        let table = fixture.table
        let context = fixture.context
        let countBefore = try context.fetch(FetchDescriptor<Block>()).count

        controller.removeTableColumn(table, at: 1)

        #expect(table.tableColumnCount == 2)
        try context.save()
        let countAfter = try context.fetch(FetchDescriptor<Block>()).count
        // 1 cellule par ligne (2 lignes) a disparu du store.
        #expect(countAfter == countBefore - 2)
    }

    @Test("removeTableColumn(_:at:) sur la DERNIERE colonne supprime le tableau entier (dissolution)")
    func removeLastColumnDissolvesTable() throws {
        let fixture = try makeControllerWithTable(rows: 2, columns: 1)
        let controller = fixture.controller
        let table = fixture.table
        let context = fixture.context

        controller.removeTableColumn(table, at: 0)
        try context.save()

        let remaining = try context.fetch(FetchDescriptor<Block>())
        #expect(!remaining.contains { $0.id == table.id })
    }

    // MARK: - Largeur de colonne

    @Test("setTableColumnWidth(_:forColumnAt:in:) applique la largeur a toutes les lignes")
    func setColumnWidthAppliesToAllRows() throws {
        let fixture = try makeControllerWithTable(rows: 3, columns: 2)
        let controller = fixture.controller
        let table = fixture.table

        controller.setTableColumnWidth(200, forColumnAt: 0, in: table)

        for row in table.tableRows {
            #expect(row.tableCells[0].attributes.columnWidth == 200)
        }
    }

    @Test("deleteBlock(_:) sur un tableau (menu de bloc generique) purge TOUT le sous-arbre du ModelContext")
    func deleteBlockOnTablePurgesEntireSubtreeFromContext() throws {
        let fixture = try makeControllerWithTable(rows: 2, columns: 2)
        let controller = fixture.controller
        let table = fixture.table
        let context = fixture.context
        // 1 table + 2 rows + 4 cells = 7 blocs avant suppression.
        let countBefore = try context.fetch(FetchDescriptor<Block>()).count
        #expect(countBefore == 7)

        // Chemin du menu de bloc GENERIQUE (`BlockTreeView`), distinct de
        // `removeTableRow`/`removeTableColumn` : c'est celui qui manquait le
        // `ModelContext.delete(_:)` avant cette revue.
        controller.deleteBlock(table)
        try context.save()

        let remaining = try context.fetch(FetchDescriptor<Block>())
        #expect(!remaining.contains { $0.id == table.id })
        // Le tableau ENTIER (table + 2 rows + 4 cells) doit avoir disparu du store, pas
        // seulement s'etre detache du document en memoire : sinon les lignes/cellules
        // restent des enregistrements orphelins persistes indefiniment. Le tableau etait
        // l'UNIQUE bloc racine de la note : le filet de non-vacuite de
        // `BlockOperations.removeSubtree(_:from:)` insere un paragraphe de secours a la
        // place, d'ou le "+1" (voir aussi `removeLastRowDissolvesTable` ci-dessus).
        #expect(remaining.count == countBefore - 7 + 1)
        #expect(remaining.allSatisfy { $0.type != .tableRow && $0.type != .tableCell })
    }

    // MARK: - Texte de cellule

    @Test("setTableCellText(_:in:) reecrit le texte d'une cellule")
    func setCellTextWritesPlainText() throws {
        let fixture = try makeControllerWithTable(rows: 1, columns: 1)
        let controller = fixture.controller
        let table = fixture.table
        let cell = table.tableRows[0].tableCells[0]

        controller.setTableCellText("Bonjour", in: cell)

        #expect(cell.text?.plainText == "Bonjour")
    }
}
