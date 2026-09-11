import Foundation
import SlateModel
import Testing

@testable import SlateEditor

/// `TableNavigation` : navigation clavier entre cellules d'un tableau (docs/08, "Tab
/// cellule suivante... fleches pour naviguer"). Construit un tableau via
/// `Block.makeTable` (comme `BlockTableStructureTests` cote `SlateModel`), sans
/// `ModelContext` ni SwiftUI.
@MainActor
@Suite("TableNavigation")
struct TableNavigationTests {
    @Test("nextCell(after:) avance dans la meme ligne")
    func nextCellWithinRow() {
        let table = Block.makeTable(rows: 2, columns: 3)
        let firstRow = table.tableRows[0]
        let cells = firstRow.tableCells

        #expect(TableNavigation.nextCell(after: cells[0])?.id == cells[1].id)
        #expect(TableNavigation.nextCell(after: cells[1])?.id == cells[2].id)
    }

    @Test("nextCell(after:) passe a la premiere cellule de la ligne suivante en fin de ligne")
    func nextCellWrapsToNextRow() {
        let table = Block.makeTable(rows: 2, columns: 3)
        let lastCellOfFirstRow = table.tableRows[0].tableCells.last
        let firstCellOfSecondRow = table.tableRows[1].tableCells.first

        let next = lastCellOfFirstRow.flatMap(TableNavigation.nextCell(after:))

        #expect(next?.id == firstCellOfSecondRow?.id)
    }

    @Test("nextCell(after:) est nil sur la derniere cellule du tableau (pas de bouclage)")
    func nextCellNilAtVeryLastCell() {
        let table = Block.makeTable(rows: 2, columns: 2)
        let veryLastCell = table.tableRows.last?.tableCells.last

        let next = veryLastCell.flatMap(TableNavigation.nextCell(after:))

        #expect(next == nil)
    }

    @Test("previousCell(before:) est symmetrique de nextCell(after:), y compris a travers les lignes")
    func previousCellSymmetric() {
        let table = Block.makeTable(rows: 2, columns: 3)
        let firstCellOfSecondRow = table.tableRows[1].tableCells[0]
        let lastCellOfFirstRow = table.tableRows[0].tableCells.last

        let previous = TableNavigation.previousCell(before: firstCellOfSecondRow)

        #expect(previous?.id == lastCellOfFirstRow?.id)
    }

    @Test("previousCell(before:) est nil sur la toute premiere cellule du tableau")
    func previousCellNilAtVeryFirstCell() {
        let table = Block.makeTable(rows: 2, columns: 2)
        let firstCell = table.tableRows[0].tableCells[0]

        #expect(TableNavigation.previousCell(before: firstCell) == nil)
    }

    @Test("cell(below:)/cell(above:) naviguent dans la meme colonne")
    func verticalNavigationStaysInColumn() {
        let table = Block.makeTable(rows: 3, columns: 3)
        let middleColumnIndex = 1
        let topCell = table.tableRows[0].tableCells[middleColumnIndex]
        let middleCell = table.tableRows[1].tableCells[middleColumnIndex]
        let bottomCell = table.tableRows[2].tableCells[middleColumnIndex]

        #expect(TableNavigation.cell(below: topCell)?.id == middleCell.id)
        #expect(TableNavigation.cell(below: middleCell)?.id == bottomCell.id)
        #expect(TableNavigation.cell(above: bottomCell)?.id == middleCell.id)
        #expect(TableNavigation.cell(above: topCell) == nil)
        #expect(TableNavigation.cell(below: bottomCell) == nil)
    }
}
