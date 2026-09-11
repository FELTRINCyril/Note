import Foundation
import SlateModel
import SwiftUI
import Testing

@testable import SlateEditor

/// `ColumnStructure` : creation/dissolution de `columnList`/`column` par depot lateral
/// (docs/10_dragdrop_colonnes.md). Point de vigilance n°1 de la tache : integrite
/// `order`/`parent` apres chaque operation, et aucun bloc orphelin dans le graphe.
@MainActor
struct ColumnStructureTests {
    // MARK: - Creation

    @Test("createColumns place target et moved dans 2 colonnes, a la position exacte de target")
    func createColumnsBuildsTwoColumnStructure() {
        let note = Note(title: "Test")
        let before = Block(order: 0, type: .paragraph, text: RichText(plainText: "Avant"), note: note)
        let target = Block(order: 1, type: .paragraph, text: RichText(plainText: "Cible"), note: note)
        let after = Block(order: 2, type: .paragraph, text: RichText(plainText: "Apres"), note: note)
        let moved = Block(order: 3, type: .paragraph, text: RichText(plainText: "Deplace"), note: note)
        note.blocks = [before, target, after, moved]

        let columnList = ColumnStructure.createColumns(target: target, moved: moved, edge: .trailing)

        let topLevel = BlockOrdering.topLevelBlocks(of: note)
        #expect(topLevel.map(\.id) == [before.id, columnList.id, after.id])
        #expect(topLevel.map(\.order) == [0, 1, 2])

        let columns = BlockOrdering.children(of: columnList)
        #expect(columns.count == 2)
        #expect(columns.map(\.type) == [.column, .column])
        #expect(columns.map(\.order) == [0, 1])

        // Depot sur le bord DROIT (`.trailing`) : target reste a gauche, moved a droite.
        #expect(BlockOrdering.children(of: columns[0]).map(\.id) == [target.id])
        #expect(BlockOrdering.children(of: columns[1]).map(\.id) == [moved.id])
        #expect(target.parent?.id == columns[0].id)
        #expect(moved.parent?.id == columns[1].id)
    }

    @Test("createColumns sur le bord GAUCHE inverse l'ordre des colonnes")
    func createColumnsLeadingEdgePlacesMovedFirst() {
        let note = Note(title: "Test")
        let target = Block(order: 0, type: .paragraph, text: RichText(plainText: "Cible"), note: note)
        let moved = Block(order: 1, type: .paragraph, text: RichText(plainText: "Deplace"), note: note)
        note.blocks = [target, moved]

        let columnList = ColumnStructure.createColumns(target: target, moved: moved, edge: .leading)
        let columns = BlockOrdering.children(of: columnList)

        #expect(BlockOrdering.children(of: columns[0]).map(\.id) == [moved.id])
        #expect(BlockOrdering.children(of: columns[1]).map(\.id) == [target.id])
    }

    @Test("createColumns conserve les enfants propres de target (pas une suppression)")
    func createColumnsPreservesTargetChildren() {
        let note = Note(title: "Test")
        let target = Block(order: 0, type: .bulletedList, text: RichText(plainText: "Item"), note: note)
        let targetChild = Block(order: 0, type: .bulletedList, note: note, parent: target)
        target.children = [targetChild]
        let moved = Block(order: 1, type: .paragraph, note: note)
        note.blocks = [target, targetChild, moved]

        let columnList = ColumnStructure.createColumns(target: target, moved: moved, edge: .trailing)
        let firstColumn = BlockOrdering.children(of: columnList)[0]

        #expect(BlockOrdering.children(of: target).map(\.id) == [targetChild.id])
        #expect(BlockOrdering.children(of: firstColumn).map(\.id) == [target.id])
    }

    // MARK: - Fractions

    @Test("widthFractions repartit egalement en l'absence de ratio memorise")
    func widthFractionsDefaultsToEqualSplit() {
        let note = Note(title: "Test")
        let target = Block(order: 0, type: .paragraph, note: note)
        let moved = Block(order: 1, type: .paragraph, note: note)
        note.blocks = [target, moved]
        let columnList = ColumnStructure.createColumns(target: target, moved: moved, edge: .trailing)
        for column in BlockOrdering.children(of: columnList) {
            column.attributes.columnWidthRatio = nil
        }

        let fractions = ColumnStructure.widthFractions(for: columnList)

        #expect(fractions.count == 2)
        #expect(abs(fractions[0] - 0.5) < 0.0001)
        #expect(abs(fractions[1] - 0.5) < 0.0001)
    }

    @Test("applyFractions ecrit un ratio normalise par colonne")
    func applyFractionsWritesNormalizedRatios() {
        let note = Note(title: "Test")
        let target = Block(order: 0, type: .paragraph, note: note)
        let moved = Block(order: 1, type: .paragraph, note: note)
        note.blocks = [target, moved]
        let columnList = ColumnStructure.createColumns(target: target, moved: moved, edge: .trailing)

        ColumnStructure.applyFractions([1, 3], to: columnList)
        let columns = BlockOrdering.children(of: columnList)

        #expect(abs((columns[0].attributes.columnWidthRatio ?? 0) - 0.25) < 0.0001)
        #expect(abs((columns[1].attributes.columnWidthRatio ?? 0) - 0.75) < 0.0001)
    }

    // MARK: - Ajout d'une 3e/4e colonne, plafond a 4

    @Test("addColumn ajoute une colonne a l'index demande et redistribue les fractions")
    func addColumnInsertsAtIndex() {
        let note = Note(title: "Test")
        let target = Block(order: 0, type: .paragraph, note: note)
        let moved = Block(order: 1, type: .paragraph, note: note)
        let third = Block(order: 2, type: .paragraph, text: RichText(plainText: "Troisieme"), note: note)
        note.blocks = [target, moved, third]
        let columnList = ColumnStructure.createColumns(target: target, moved: moved, edge: .trailing)

        let added = ColumnStructure.addColumn(moved: third, to: columnList, at: 1)

        #expect(added)
        let columns = BlockOrdering.children(of: columnList)
        #expect(columns.count == 3)
        #expect(BlockOrdering.children(of: columns[1]).map(\.id) == [third.id])
        for column in columns {
            #expect(abs((column.attributes.columnWidthRatio ?? 0) - (1.0 / 3.0)) < 0.0001)
        }
    }

    @Test("addColumn refuse une 5e colonne (maximum 4)")
    func addColumnRejectsBeyondMax() throws {
        let note = Note(title: "Test")
        var blocks: [Block] = []
        for index in 0..<5 {
            blocks.append(Block(order: index, type: .paragraph, note: note))
        }
        note.blocks = blocks
        var columnList = ColumnStructure.createColumns(target: blocks[0], moved: blocks[1], edge: .trailing)
        _ = ColumnStructure.addColumn(moved: blocks[2], to: columnList, at: 2)
        _ = ColumnStructure.addColumn(moved: blocks[3], to: columnList, at: 3)
        columnList = try #require(BlockOrdering.topLevelBlocks(of: note).first { $0.id == columnList.id })

        let added = ColumnStructure.addColumn(moved: blocks[4], to: columnList, at: 4)

        #expect(!added)
        #expect(BlockOrdering.children(of: columnList).count == 4)
    }

    @Test("addColumn refuse un tableau (une colonne accepte tout sauf un tableau)")
    func addColumnRejectsTable() {
        let note = Note(title: "Test")
        let target = Block(order: 0, type: .paragraph, note: note)
        let moved = Block(order: 1, type: .paragraph, note: note)
        let table = Block.makeTable(rows: 2, columns: 2)
        table.order = 2
        table.note = note
        note.blocks = [target, moved, table]
        let columnList = ColumnStructure.createColumns(target: target, moved: moved, edge: .trailing)

        let added = ColumnStructure.addColumn(moved: table, to: columnList, at: 0)

        #expect(!added)
        #expect(BlockOrdering.children(of: columnList).count == 2)
    }

    // MARK: - Dissolution

    @Test("dissolveIfNeeded retire une colonne devenue vide sans dissoudre la structure")
    func dissolveIfNeededRemovesEmptyColumnOnly() {
        let note = Note(title: "Test")
        let target = Block(order: 0, type: .paragraph, note: note)
        let moved = Block(order: 1, type: .paragraph, note: note)
        let third = Block(order: 2, type: .paragraph, note: note)
        note.blocks = [target, moved, third]
        let columnList = ColumnStructure.createColumns(target: target, moved: moved, edge: .trailing)
        _ = ColumnStructure.addColumn(moved: third, to: columnList, at: 2)
        let emptiedColumn = BlockOrdering.children(of: columnList)[1]
        emptiedColumn.children = [] // simule le retrait de son seul bloc par l'appelant

        let orphaned = ColumnStructure.dissolveIfNeeded(columnList)

        let remainingColumns = BlockOrdering.children(of: columnList)
        #expect(remainingColumns.count == 2)
        #expect(orphaned.map(\.id) == [emptiedColumn.id])
        #expect(emptiedColumn.parent == nil)
        #expect(emptiedColumn.note == nil)
        // Le columnList lui-meme reste en place, toujours a la racine.
        #expect(BlockOrdering.topLevelBlocks(of: note).contains { $0.id == columnList.id })
    }

    @Test("dissolveIfNeeded dissout completement la structure s'il ne reste qu'une colonne")
    func dissolveIfNeededDissolvesWhenOneColumnRemains() {
        let note = Note(title: "Test")
        let before = Block(order: 0, type: .paragraph, text: RichText(plainText: "Avant"), note: note)
        let target = Block(order: 1, type: .paragraph, text: RichText(plainText: "Cible"), note: note)
        let moved = Block(order: 2, type: .paragraph, text: RichText(plainText: "Deplace"), note: note)
        let after = Block(order: 3, type: .paragraph, text: RichText(plainText: "Apres"), note: note)
        note.blocks = [before, target, moved, after]
        let columnList = ColumnStructure.createColumns(target: target, moved: moved, edge: .trailing)
        let secondColumn = BlockOrdering.children(of: columnList)[1]
        // Simule le retrait REEL de `moved` de la colonne (deplace ailleurs, comme le
        // ferait un drag ulterieur) : `detachPreservingChildren` + reinsertion, jamais
        // un simple `secondColumn.children = []` qui laisserait `moved` demi-detache
        // (retire de la vue `children`, mais toujours rattache a `note` -- il
        // reapparaitrait alors a tort comme bloc racine des la colonne dissoute).
        BlockOrdering.detachPreservingChildren(moved)
        BlockOrdering.insert(moved, after: after)

        let orphaned = ColumnStructure.dissolveIfNeeded(columnList)

        let topLevel = BlockOrdering.topLevelBlocks(of: note)
        // La structure entiere disparait : le contenu de la colonne restante (target)
        // remonte exactement a la place qu'occupait le columnList.
        let expectedIDs: [UUID] = [before.id, target.id, after.id, moved.id]
        #expect(topLevel.map(\.id) == expectedIDs)
        #expect(topLevel.map(\.order) == [0, 1, 2, 3])
        #expect(target.parent == nil)
        #expect(target.note?.id == note.id)

        // Les 3 blocs de structure (columnList + ses 2 colonnes) sont bien orphelins,
        // prets a etre purges du ModelContext par l'appelant.
        let orphanedIDs = Set(orphaned.map(\.id))
        #expect(orphanedIDs.contains(columnList.id))
        #expect(orphanedIDs.contains(secondColumn.id))
        #expect(orphaned.allSatisfy { $0.parent == nil && $0.note == nil })
    }

    @Test("dissolveIfNeeded promeut TOUS les blocs d'une colonne multi-contenu")
    func dissolveIfNeededPromotesEveryRemainingBlock() {
        let note = Note(title: "Test")
        let target = Block(order: 0, type: .paragraph, text: RichText(plainText: "Un"), note: note)
        let moved = Block(order: 1, type: .paragraph, text: RichText(plainText: "Deux"), note: note)
        note.blocks = [target, moved]
        let columnList = ColumnStructure.createColumns(target: target, moved: moved, edge: .trailing)
        let firstColumn = BlockOrdering.children(of: columnList)[0]
        let extraInFirstColumn = Block(order: 1, type: .paragraph, text: RichText(plainText: "Trois"), note: note)
        BlockOrdering.insert(extraInFirstColumn, after: target)
        #expect(BlockOrdering.children(of: firstColumn).map(\.id) == [target.id, extraInFirstColumn.id])
        // Meme correction que `dissolveIfNeededDissolvesWhenOneColumnRemains` : retrait
        // REEL de `moved`, jamais un simple `children = []` incomplet. Reinsere au
        // niveau RACINE, juste apres `columnList` (encore en place a cet instant).
        BlockOrdering.detachPreservingChildren(moved)
        BlockOrdering.insert(moved, after: columnList)

        _ = ColumnStructure.dissolveIfNeeded(columnList)

        let topLevel = BlockOrdering.topLevelBlocks(of: note)
        // Le contenu ENTIER de la colonne restante (target ET extraInFirstColumn, dans
        // l'ordre) remonte a la place du columnList ; `moved`, deja remonte au niveau
        // racine avant la dissolution, garde sa position relative APRES ce contenu.
        #expect(topLevel.map(\.id) == [target.id, extraInFirstColumn.id, moved.id])
    }

    @Test("dissolveIfNeeded est sans effet sur un bloc qui n'est pas un columnList")
    func dissolveIfNeededNoOpOnNonColumnList() {
        let note = Note(title: "Test")
        let paragraph = Block(order: 0, type: .paragraph, note: note)
        note.blocks = [paragraph]

        let orphaned = ColumnStructure.dissolveIfNeeded(paragraph)

        #expect(orphaned.isEmpty)
        #expect(BlockOrdering.topLevelBlocks(of: note).map(\.id) == [paragraph.id])
    }
}
