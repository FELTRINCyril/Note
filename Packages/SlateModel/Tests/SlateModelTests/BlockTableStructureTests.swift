import Foundation
import SwiftData
import Testing

@testable import SlateModel

/// Tests de Phase 8 (`docs/08_blocs_speciaux.md`) : structure du tableau modelise en
/// sous-blocs (`table` -> `tableRow` -> `tableCell`), integrite (rectangularite),
/// ajout/suppression de ligne et de colonne, largeur de colonne, et round-trip
/// SwiftData des nouveaux attributs.
@MainActor
struct BlockTableStructureTests {

    // MARK: Creation

    @Test
    func makeTableBuildsRectangularGridWithCorrectOrders() {
        let table = Block.makeTable(rows: 3, columns: 4)

        #expect(table.type == .table)
        #expect(table.tableRows.count == 3)
        #expect(table.tableRows.map(\.order) == [0, 1, 2])
        #expect(table.isTableRectangular)
        #expect(table.tableColumnCount == 4)

        for row in table.tableRows {
            #expect(row.type == .tableRow)
            #expect(row.tableCells.count == 4)
            #expect(row.tableCells.map(\.order) == [0, 1, 2, 3])
            #expect(row.tableCells.allSatisfy { $0.type == .tableCell })
            #expect(row.tableCells.allSatisfy { ($0.text?.plainText ?? "").isEmpty })
            #expect(row.tableCells.allSatisfy { $0.parent?.id == row.id })
        }
    }

    @Test
    func makeTableMarksOnlyFirstRowAsHeader() {
        let table = Block.makeTable(rows: 3, columns: 2)

        #expect(table.tableRows[0].attributes.isHeaderRow == true)
        #expect(table.tableRows[1].attributes.isHeaderRow == false)
        #expect(table.tableRows[2].attributes.isHeaderRow == false)
    }

    @Test
    func nonTableOrNonRowBlocksExposeEmptyTableAccessors() {
        let paragraph = Block(type: .paragraph)
        #expect(paragraph.tableRows.isEmpty)
        #expect(paragraph.tableCells.isEmpty)
        #expect(paragraph.tableColumnCount == 0)
        // Vrai trivialement : l'invariant ne s'applique qu'aux `.table`.
        #expect(paragraph.isTableRectangular)

        let table = Block.makeTable(rows: 1, columns: 1)
        // Un `table` n'est pas lui-meme une `tableRow` : pas de cellules directes.
        #expect(table.tableCells.isEmpty)
    }

    // MARK: Ajout / suppression de ligne

    @Test
    func insertTableRowAppendsByDefaultAndReindexes() throws {
        let table = Block.makeTable(rows: 2, columns: 3)

        let newRow = try table.insertTableRow()

        #expect(table.tableRows.count == 3)
        #expect(table.tableRows.map(\.order) == [0, 1, 2])
        #expect(table.tableRows.last?.id == newRow.id)
        #expect(newRow.tableCells.count == 3)
        #expect(table.isTableRectangular)
    }

    @Test
    func insertTableRowAtSpecificIndexShiftsFollowingRows() throws {
        let table = Block.makeTable(rows: 2, columns: 2)
        let originalSecondRowID = table.tableRows[1].id

        let newRow = try table.insertTableRow(at: 1)

        #expect(table.tableRows.count == 3)
        #expect(table.tableRows[1].id == newRow.id)
        #expect(table.tableRows[2].id == originalSecondRowID)
        #expect(table.tableRows.map(\.order) == [0, 1, 2])
        #expect(table.isTableRectangular)
    }

    @Test
    func insertTableRowRejectsOutOfRangeIndex() {
        let table = Block.makeTable(rows: 2, columns: 2)

        #expect(throws: Block.TableStructureError.rowIndexOutOfRange) {
            try table.insertTableRow(at: 99)
        }
        #expect(throws: Block.TableStructureError.rowIndexOutOfRange) {
            try table.insertTableRow(at: -1)
        }
    }

    @Test
    func removeTableRowReindexesRemainingRows() throws {
        let table = Block.makeTable(rows: 3, columns: 2)
        let survivingFirstRowID = table.tableRows[0].id
        let survivingLastRowID = table.tableRows[2].id

        let removed = try table.removeTableRow(at: 1)

        #expect(table.tableRows.count == 2)
        #expect(table.tableRows.map(\.id) == [survivingFirstRowID, survivingLastRowID])
        #expect(table.tableRows.map(\.order) == [0, 1])
        #expect(removed.parent == nil)
        #expect(table.isTableRectangular)
    }

    @Test
    func removeTableRowRejectsOutOfRangeIndex() {
        let table = Block.makeTable(rows: 2, columns: 2)

        #expect(throws: Block.TableStructureError.rowIndexOutOfRange) {
            try table.removeTableRow(at: 5)
        }
    }

    /// Decision de conception : la derniere ligne d'un tableau ne peut pas etre
    /// retiree par cette API (refus, pas de dissolution du tableau). Voir la
    /// documentation de `removeTableRow` dans `Block+Table.swift`.
    @Test
    func removeTableRowRefusesToRemoveTheLastRow() {
        let table = Block.makeTable(rows: 1, columns: 3)

        #expect(throws: Block.TableStructureError.cannotRemoveLastRow) {
            try table.removeTableRow(at: 0)
        }
        #expect(table.tableRows.count == 1)
    }

    // MARK: Ajout / suppression de colonne

    @Test
    func insertTableColumnTouchesEveryRow() throws {
        let table = Block.makeTable(rows: 3, columns: 2)

        let newCells = try table.insertTableColumn()

        #expect(newCells.count == 3)
        #expect(table.tableColumnCount == 3)
        #expect(table.isTableRectangular)
        for row in table.tableRows {
            #expect(row.tableCells.count == 3)
            #expect(row.tableCells.map(\.order) == [0, 1, 2])
        }
    }

    @Test
    func insertTableColumnAtSpecificIndexShiftsFollowingColumnsInEveryRow() throws {
        let table = Block.makeTable(rows: 2, columns: 2)
        let originalSecondColumnIDs = table.tableRows.map { $0.tableCells[1].id }

        let newCells = try table.insertTableColumn(at: 1)

        for (rowIndex, row) in table.tableRows.enumerated() {
            #expect(row.tableCells.count == 3)
            #expect(row.tableCells[1].id == newCells[rowIndex].id)
            #expect(row.tableCells[2].id == originalSecondColumnIDs[rowIndex])
        }
        #expect(table.isTableRectangular)
    }

    @Test
    func insertTableColumnRejectsOutOfRangeIndex() {
        let table = Block.makeTable(rows: 2, columns: 2)

        #expect(throws: Block.TableStructureError.columnIndexOutOfRange) {
            try table.insertTableColumn(at: 99)
        }
    }

    @Test
    func removeTableColumnTouchesEveryRowAndReindexes() throws {
        let table = Block.makeTable(rows: 3, columns: 3)
        let survivingColumnIDsByRow = table.tableRows.map { row in
            [row.tableCells[0].id, row.tableCells[2].id]
        }

        let removedCells = try table.removeTableColumn(at: 1)

        #expect(removedCells.count == 3)
        #expect(table.tableColumnCount == 2)
        #expect(table.isTableRectangular)
        for (rowIndex, row) in table.tableRows.enumerated() {
            #expect(row.tableCells.map(\.id) == survivingColumnIDsByRow[rowIndex])
            #expect(row.tableCells.map(\.order) == [0, 1])
        }
        #expect(removedCells.allSatisfy { $0.parent == nil })
    }

    @Test
    func removeTableColumnRejectsOutOfRangeIndex() {
        let table = Block.makeTable(rows: 2, columns: 2)

        #expect(throws: Block.TableStructureError.columnIndexOutOfRange) {
            try table.removeTableColumn(at: 5)
        }
    }

    /// Meme decision que pour la ligne : refus, pas de dissolution. Voir
    /// `removeTableRowRefusesToRemoveTheLastRow`.
    @Test
    func removeTableColumnRefusesToRemoveTheLastColumn() {
        let table = Block.makeTable(rows: 2, columns: 1)

        #expect(throws: Block.TableStructureError.cannotRemoveLastColumn) {
            try table.removeTableColumn(at: 0)
        }
        #expect(table.tableColumnCount == 1)
    }

    @Test
    func operationsOnNonTableBlockThrowNotATable() {
        let paragraph = Block(type: .paragraph)

        #expect(throws: Block.TableStructureError.notATable) {
            try paragraph.insertTableRow()
        }
        #expect(throws: Block.TableStructureError.notATable) {
            try paragraph.removeTableRow(at: 0)
        }
        #expect(throws: Block.TableStructureError.notATable) {
            try paragraph.insertTableColumn()
        }
        #expect(throws: Block.TableStructureError.notATable) {
            try paragraph.removeTableColumn(at: 0)
        }
        #expect(throws: Block.TableStructureError.notATable) {
            try paragraph.setTableColumnWidth(100, forColumnAt: 0)
        }
    }

    // MARK: Largeur de colonne

    @Test
    func setTableColumnWidthAppliesToEveryRowConsistently() throws {
        let table = Block.makeTable(rows: 3, columns: 2)

        try table.setTableColumnWidth(184, forColumnAt: 0)

        for row in table.tableRows {
            #expect(row.tableCells[0].attributes.columnWidth == 184)
            #expect(row.tableCells[1].attributes.columnWidth == nil)
        }
    }

    @Test
    func setTableColumnWidthRejectsOutOfRangeIndex() {
        let table = Block.makeTable(rows: 2, columns: 2)

        #expect(throws: Block.TableStructureError.columnIndexOutOfRange) {
            try table.setTableColumnWidth(100, forColumnAt: 7)
        }
    }

    // MARK: Round-trip SwiftData (fetch reel, motif d'`EntityGraphTests`)

    /// Insere un tableau complet (avec largeur de colonne et ligne d'en-tete) dans un
    /// vrai `ModelContainer`, sauvegarde, puis relit via un `ModelContext` frais : c'est
    /// la seule preuve honnete qu'aucun attribut ne se perd au passage par le store
    /// (pas seulement une manipulation en memoire des instances d'origine).
    @Test
    func tableAndItsAttributesRoundTripThroughRealFetch() throws {
        let container = try SlateContainer.make(inMemory: true)
        let context = ModelContext(container)

        let note = Note(title: "Suivi de chantier")
        let table = Block.makeTable(rows: 2, columns: 3, note: note)
        try table.setTableColumnWidth(184, forColumnAt: 0)
        table.tableRows[1].tableCells[0].text = RichText(plainText: "Editeur de blocs")
        note.blocks = [table]

        func insertRecursively(_ block: Block) {
            context.insert(block)
            for child in block.children ?? [] {
                insertRecursively(child)
            }
        }
        context.insert(note)
        insertRecursively(table)
        try context.save()

        let freshContext = ModelContext(container)
        let fetchedNote = try #require(freshContext.fetch(FetchDescriptor<Note>()).first)
        let fetchedTable = try #require((fetchedNote.blocks ?? []).first { $0.type == .table })

        #expect(fetchedTable.tableRows.count == 2)
        #expect(fetchedTable.isTableRectangular)

        let headerRow = try #require(fetchedTable.tableRows.first)
        #expect(headerRow.attributes.isHeaderRow == true)
        #expect(headerRow.tableCells[0].attributes.columnWidth == 184)
        #expect(headerRow.tableCells[1].attributes.columnWidth == nil)

        let secondRow = fetchedTable.tableRows[1]
        #expect(secondRow.attributes.isHeaderRow == false)
        #expect(secondRow.tableCells[0].text?.plainText == "Editeur de blocs")
        #expect(secondRow.tableCells[0].attributes.columnWidth == 184)

        // Suppression en cascade : supprimer le `table` retire toutes ses lignes et
        // cellules (meme motif que `deletingBlockCascadesToChildrenAndAttachmentOnly`
        // dans `EntityGraphTests`).
        let blocksBeforeDeletion = try freshContext.fetch(FetchDescriptor<Block>())
        #expect(blocksBeforeDeletion.count == 1 + 2 + (2 * 3))

        freshContext.delete(fetchedTable)
        try freshContext.save()

        let blocksAfterDeletion = try freshContext.fetch(FetchDescriptor<Block>())
        #expect(blocksAfterDeletion.isEmpty)
    }

    // MARK: Note.refreshDerivedText et cellules de tableau

    @Test
    func tableCellTextContributesToNoteDerivedTextInRowThenColumnOrder() {
        let note = Note(title: "Suivi")
        let table = Block.makeTable(rows: 2, columns: 2, order: 0, note: note)
        table.tableRows[0].tableCells[0].text = RichText(plainText: "Chantier")
        table.tableRows[0].tableCells[1].text = RichText(plainText: "Responsable")
        table.tableRows[1].tableCells[0].text = RichText(plainText: "Editeur de blocs")
        table.tableRows[1].tableCells[1].text = RichText(plainText: "Camille")
        note.blocks = [table]

        note.refreshDerivedText()

        #expect(note.plainText == "Chantier\nResponsable\nEditeur de blocs\nCamille")
    }

    @Test
    func emptyTableCellsDoNotPolluteNoteDerivedText() {
        let note = Note(title: "Suivi")
        let table = Block.makeTable(rows: 1, columns: 2, order: 0, note: note)
        table.tableRows[0].tableCells[0].text = RichText(plainText: "Seule cellule remplie")
        note.blocks = [table]

        note.refreshDerivedText()

        #expect(note.plainText == "Seule cellule remplie")
    }
}
