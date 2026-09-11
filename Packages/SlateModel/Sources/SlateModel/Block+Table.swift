import Foundation

/// Logique d'integrite d'un tableau (`BlockType.table`), en Swift pur, independante de
/// tout `ModelContext` et de toute vue : testable directement (voir
/// `BlockTableStructureTests`).
///
/// ## Decision structurante : sous-blocs, pas une grille dans `BlockAttributes`
///
/// Un `table` porte des `tableRow` enfants (`Block.children`), chaque `tableRow` porte
/// des `tableCell` enfants, chaque `tableCell` porte son propre `Block.text`. Aucune
/// grille n'est stockee dans `BlockAttributes`.
///
/// Raison technique dure (pas une preference) : `BlockAttributes` est une propriete
/// `@Model` serialisee par le "composite coder" de SwiftData, qui ne sait descendre que
/// dans des conteneurs Codable **keyed**. Une grille imbriquee (`[[Cell]]` ou
/// equivalent) produirait un conteneur **unkeyed** imbrique des le premier niveau
/// (`Array` encode nativement dans un `unkeyedContainer`), exactement le piege n°2 de
/// `docs/DEV_ENV.md` deja rencontre en Phase 2 sur `RichText`/`AttributedString` : un
/// `fatalError` ("Composite Coder only supports Keyed Container") au premier acces,
/// pas une erreur de compilation, pas une exception rattrapable. La modelisation en
/// sous-blocs suit le precedent deja pose par `columnList`/`column` dans `BlockType`.
extension Block {
    /// Erreurs de l'API d'edition structurelle d'un tableau. Un enum plat (pas de
    /// valeur associee portant un `Block`) : l'appelant a deja la reference en cause.
    public enum TableStructureError: Error, Equatable, Sendable {
        /// L'operation a ete demandee sur un bloc qui n'est pas de type `.table` (pour
        /// `insertTableRow`/`removeTableRow`/`insertTableColumn`/`removeTableColumn`/
        /// `setTableColumnWidth`), ou pas de type `.tableRow` la ou une ligne est
        /// attendue.
        case notATable
        /// Index de ligne hors bornes (`removeTableRow`, ou `insertTableRow` avec un
        /// index qui ne serait pas dans `0...tableRows.count`).
        case rowIndexOutOfRange
        /// Index de colonne hors bornes, meme logique que `rowIndexOutOfRange`.
        case columnIndexOutOfRange
        /// Refus : un tableau garde toujours au moins une ligne. Voir la note de
        /// conception de `removeTableRow`.
        case cannotRemoveLastRow
        /// Refus : un tableau garde toujours au moins une colonne. Meme motif que
        /// `cannotRemoveLastRow`, voir `removeTableColumn`.
        case cannotRemoveLastColumn
    }

    /// Construit un tableau complet `rows` x `columns`, avec ses sous-blocs `tableRow`
    /// puis `tableCell` (chaque cellule avec un `RichText` vide). La premiere ligne est
    /// marquee ligne d'en-tete (`BlockAttributes.isHeaderRow`), coherent avec l'artboard
    /// H du design (`design/_design_complet/Slate P1 - Formatage & blocs.dc.html`,
    /// ligne 413).
    ///
    /// Ne fait aucune insertion dans un `ModelContext` : comme le reste du modele (voir
    /// `EntityGraphTests`), c'est a l'appelant d'inserer chaque bloc (le `table` retourne
    /// et tous ses descendants, atteignables recursivement via `children`).
    public static func makeTable(
        rows: Int,
        columns: Int,
        order: Int = 0,
        note: Note? = nil,
        parent: Block? = nil
    ) -> Block {
        precondition(rows > 0, "Un tableau doit avoir au moins une ligne")
        precondition(columns > 0, "Un tableau doit avoir au moins une colonne")

        let table = Block(order: order, type: .table, note: note, parent: parent)
        table.children = (0..<rows).map { rowIndex in
            makeTableRow(columns: columns, order: rowIndex, isHeaderRow: rowIndex == 0, note: note, parent: table)
        }
        return table
    }

    private static func makeTableRow(
        columns: Int,
        order: Int,
        isHeaderRow: Bool,
        note: Note?,
        parent: Block
    ) -> Block {
        let row = Block(order: order, type: .tableRow, note: note, parent: parent)
        row.attributes.isHeaderRow = isHeaderRow
        row.children = (0..<columns).map { columnIndex in
            Block(order: columnIndex, type: .tableCell, text: RichText(plainText: ""), note: note, parent: row)
        }
        return row
    }

    /// Lignes de ce tableau, triees par `order`. Vide si ce bloc n'est pas un `.table`.
    public var tableRows: [Block] {
        guard type == .table else { return [] }
        return (children ?? []).filter { $0.type == .tableRow }.sorted { $0.order < $1.order }
    }

    /// Cellules de cette ligne, triees par `order`. Vide si ce bloc n'est pas une
    /// `.tableRow`.
    public var tableCells: [Block] {
        guard type == .tableRow else { return [] }
        return (children ?? []).filter { $0.type == .tableCell }.sorted { $0.order < $1.order }
    }

    /// Nombre de colonnes, deduit de la premiere ligne. 0 si le tableau n'a pas encore
    /// de ligne (etat transitoire uniquement : aucune fonction de ce fichier ne produit
    /// cet etat, `removeTableRow` refuse de vider la derniere ligne).
    public var tableColumnCount: Int {
        tableRows.first?.tableCells.count ?? 0
    }

    /// Invariant de rectangularite : toutes les lignes ont le meme nombre de cellules.
    /// Vrai trivialement pour un bloc qui n'est pas un `.table`.
    public var isTableRectangular: Bool {
        guard type == .table else { return true }
        let counts = tableRows.map { $0.tableCells.count }
        guard let firstCount = counts.first else { return true }
        return counts.allSatisfy { $0 == firstCount }
    }

    /// Insere une nouvelle ligne (avec autant de cellules que les lignes existantes,
    /// texte vide) a l'index donne (par defaut, en derniere position). Reindexe
    /// l'`order` de toutes les lignes pour rester coherent.
    @discardableResult
    public func insertTableRow(at index: Int? = nil) throws -> Block {
        guard type == .table else { throw TableStructureError.notATable }
        var rows = tableRows
        let insertIndex = index ?? rows.count
        guard insertIndex >= 0, insertIndex <= rows.count else { throw TableStructureError.rowIndexOutOfRange }

        let newRow = Self.makeTableRow(
            columns: max(tableColumnCount, 1),
            order: insertIndex,
            isHeaderRow: false,
            note: note,
            parent: self
        )
        rows.insert(newRow, at: insertIndex)
        Self.reindex(rows)
        children = rows
        return newRow
    }

    /// Retire la ligne a l'index donne. Refuse (`cannotRemoveLastRow`) si c'est la
    /// derniere ligne du tableau : voir la note de conception ci-dessous.
    ///
    /// Ne supprime pas le bloc retire d'un `ModelContext` : cette fonction manipule
    /// uniquement le graphe en memoire (`children`), comme le reste du modele (voir
    /// `EntityGraphTests`). Si le tableau est persiste, l'appelant doit
    /// `context.delete(...)` le bloc retourne pour que la suppression atteigne le
    /// store (la cascade de `Block.children` s'occupe alors de ses cellules).
    ///
    /// ## Choix : refuser plutot que dissoudre
    /// Supprimer la derniere ligne (ou colonne, voir `removeTableColumn`) rendrait un
    /// tableau a 0 ligne ou 0 colonne : un etat qui ne correspond a rien d'affichable et
    /// casse `tableColumnCount`/`isTableRectangular`. Deux options existaient : refuser
    /// l'operation, ou "dissoudre" le tableau (le convertir en un autre type de bloc,
    /// ex. `paragraph`, quand il ne reste plus rien a afficher). La dissolution
    /// implique une decision de rendu/UX (que devient le bloc ? recupere-t-on le texte
    /// de la derniere cellule ? faut-il une confirmation ?) qui releve de l'editeur, pas
    /// du modele de donnees. Le modele reste donc conservateur : il garantit
    /// l'invariant "un tableau a toujours au moins une ligne et une colonne" en
    /// refusant l'operation qui le violerait, et laisse `SlateEditor` decider
    /// explicitement de supprimer le bloc `table` entier si c'est le geste voulu par
    /// l'utilisateur.
    @discardableResult
    public func removeTableRow(at index: Int) throws -> Block {
        guard type == .table else { throw TableStructureError.notATable }
        var rows = tableRows
        guard index >= 0, index < rows.count else { throw TableStructureError.rowIndexOutOfRange }
        guard rows.count > 1 else { throw TableStructureError.cannotRemoveLastRow }

        let removed = rows.remove(at: index)
        removed.parent = nil
        Self.reindex(rows)
        children = rows
        return removed
    }

    /// Insere une nouvelle colonne (une cellule vide dans CHAQUE ligne existante) a
    /// l'index donne (par defaut, en derniere position). Touche toutes les lignes pour
    /// garder l'invariant de rectangularite.
    @discardableResult
    public func insertTableColumn(at index: Int? = nil) throws -> [Block] {
        guard type == .table else { throw TableStructureError.notATable }
        let rows = tableRows
        let columnCount = tableColumnCount
        let insertIndex = index ?? columnCount
        guard insertIndex >= 0, insertIndex <= columnCount else { throw TableStructureError.columnIndexOutOfRange }

        var newCells: [Block] = []
        for row in rows {
            var cells = row.tableCells
            let newCell = Block(
                order: insertIndex,
                type: .tableCell,
                text: RichText(plainText: ""),
                note: note,
                parent: row
            )
            cells.insert(newCell, at: insertIndex)
            Self.reindex(cells)
            row.children = cells
            newCells.append(newCell)
        }
        return newCells
    }

    /// Retire la colonne a l'index donne dans TOUTES les lignes. Refuse
    /// (`cannotRemoveLastColumn`) si c'est la derniere colonne. Voir la note de
    /// conception de `removeTableRow` : meme choix (refus plutot que dissolution), et
    /// meme remarque sur la non-suppression des blocs retires d'un `ModelContext`
    /// (a la charge de l'appelant).
    @discardableResult
    public func removeTableColumn(at index: Int) throws -> [Block] {
        guard type == .table else { throw TableStructureError.notATable }
        let rows = tableRows
        let columnCount = tableColumnCount
        guard index >= 0, index < columnCount else { throw TableStructureError.columnIndexOutOfRange }
        guard columnCount > 1 else { throw TableStructureError.cannotRemoveLastColumn }

        var removedCells: [Block] = []
        for row in rows {
            var cells = row.tableCells
            let removed = cells.remove(at: index)
            removed.parent = nil
            Self.reindex(cells)
            row.children = cells
            removedCells.append(removed)
        }
        return removedCells
    }

    /// Applique une largeur de colonne (en points) a la cellule de cet index dans
    /// TOUTES les lignes, pour que la largeur reste coherente colonne par colonne (voir
    /// `BlockAttributes.columnWidth`). `nil` revient a la largeur naturelle/auto.
    public func setTableColumnWidth(_ width: Double?, forColumnAt index: Int) throws {
        guard type == .table else { throw TableStructureError.notATable }
        let columnCount = tableColumnCount
        guard index >= 0, index < columnCount else { throw TableStructureError.columnIndexOutOfRange }

        for row in tableRows {
            row.tableCells[index].attributes.columnWidth = width
        }
    }

    private static func reindex(_ blocks: [Block]) {
        for (index, block) in blocks.enumerated() {
            block.order = index
        }
    }
}
