import Foundation
import SlateModel

/// Logique PURE (aucune dependance AppKit/SwiftUI) de la navigation clavier entre
/// cellules d'un tableau (docs/08_blocs_speciaux.md, "Navigation clavier entre
/// cellules"). Chaque fonction prend une `tableCell` et retourne la cellule cible, ou
/// `nil` en bord de tableau (aucun wraparound -- coherent avec le reste du projet, voir
/// `BlockOrdering.block(before:)`/`block(after:)`). Testable directement sur un graphe
/// `Note`/`Block` en memoire, sans `TableBlockContentView` ni fenetre.
@MainActor
public enum TableNavigation {
    /// Cellule suivante pour Tab : la cellule a droite dans la meme ligne, ou la
    /// PREMIERE cellule de la ligne suivante si `cell` est la derniere de sa ligne.
    /// `nil` si `cell` est la derniere cellule de la derniere ligne (pas de bouclage
    /// automatique vers une nouvelle ligne -- voir la documentation de tete de fichier
    /// de `EditorController+Table.swift` pour l'insertion explicite d'une ligne/colonne).
    public static func nextCell(after cell: Block) -> Block? {
        guard let row = cell.parent, let table = row.parent else { return nil }
        let cellsInRow = row.tableCells
        guard let cellIndex = cellsInRow.firstIndex(where: { $0.id == cell.id }) else { return nil }

        if cellIndex + 1 < cellsInRow.count {
            return cellsInRow[cellIndex + 1]
        }

        let rows = table.tableRows
        guard let rowIndex = rows.firstIndex(where: { $0.id == row.id }), rowIndex + 1 < rows.count else {
            return nil
        }
        return rows[rowIndex + 1].tableCells.first
    }

    /// Symmetrique de `nextCell(after:)` pour Maj+Tab : la cellule a gauche dans la meme
    /// ligne, ou la DERNIERE cellule de la ligne precedente si `cell` est la premiere de
    /// sa ligne. `nil` si `cell` est la toute premiere cellule du tableau.
    public static func previousCell(before cell: Block) -> Block? {
        guard let row = cell.parent, let table = row.parent else { return nil }
        let cellsInRow = row.tableCells
        guard let cellIndex = cellsInRow.firstIndex(where: { $0.id == cell.id }) else { return nil }

        if cellIndex > 0 {
            return cellsInRow[cellIndex - 1]
        }

        let rows = table.tableRows
        guard let rowIndex = rows.firstIndex(where: { $0.id == row.id }), rowIndex > 0 else { return nil }
        return rows[rowIndex - 1].tableCells.last
    }

    /// Fleche bas : la cellule de MEME colonne, dans la ligne suivante. `nil` si `cell`
    /// est deja dans la derniere ligne.
    public static func cell(below cell: Block) -> Block? {
        guard let row = cell.parent, let table = row.parent else { return nil }
        let columnIndex = cell.order
        let rows = table.tableRows
        guard let rowIndex = rows.firstIndex(where: { $0.id == row.id }), rowIndex + 1 < rows.count else {
            return nil
        }
        let nextRowCells = rows[rowIndex + 1].tableCells
        guard columnIndex < nextRowCells.count else { return nil }
        return nextRowCells[columnIndex]
    }

    /// Fleche haut : symmetrique de `cell(below:)`. `nil` si `cell` est deja dans la
    /// premiere ligne.
    public static func cell(above cell: Block) -> Block? {
        guard let row = cell.parent, let table = row.parent else { return nil }
        let columnIndex = cell.order
        let rows = table.tableRows
        guard let rowIndex = rows.firstIndex(where: { $0.id == row.id }), rowIndex > 0 else { return nil }
        let previousRowCells = rows[rowIndex - 1].tableCells
        guard columnIndex < previousRowCells.count else { return nil }
        return previousRowCells[columnIndex]
    }
}
