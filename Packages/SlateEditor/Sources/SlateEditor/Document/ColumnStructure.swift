import CoreGraphics
import SlateModel
import SlateUI
import SwiftUI

/// Logique PURE (aucune dependance AppKit, aucun `ModelContext`) de creation/
/// dissolution de la mise en colonnes (`BlockType.columnList`/`.column`, Phase 10,
/// docs/10_dragdrop_colonnes.md, artboard J). Memes principes que `BlockOrdering`/
/// `BlockOperations` : opere directement sur le graphe `Block`/`Note` deja en memoire,
/// entierement testable sans `NSTextView` ni fenetre. `EditorController` reste la SEULE
/// facade appelee par la couche SwiftUI.
///
/// ## Integrite `order`/`parent` -- le point de vigilance de la tache
/// Chaque fonction ici reutilise EXCLUSIVEMENT les primitives PUBLIQUES/`internal` deja
/// EPROUVEES de `BlockOrdering` (`insert(_:after:)`/`detachPreservingChildren(_:)`/
/// `children(of:)`), plutot que de reimplementer sa propre algebre de `order`/
/// `note.blocks` -- une premiere version de ce fichier le faisait (voir l'historique
/// git) et laissait filtrer des "blocs fantomes" (`BlockOrderingCache.swift`) des que
/// deux mutations de la fratrie racine s'enchainaient sans lecture entre les deux : le
/// cache aplati, construit paresseusement au premier acces, peut alors rester perime
/// entre deux operations qui ne l'invalident pas explicitement toutes les deux (voir
/// `BlockOrdering.detachPreservingChildren(_:)`, qui NE le fait PAS par contrat -- a
/// l'appelant de le faire s'il enchaine une autre lecture avant son propre `attach*`).
/// Reutiliser `insert(_:after:)` (qui invalide deja lui-meme) reduit ce risque au lieu
/// de le reproduire. Comme le reste de `BlockOrdering`, ces fonctions DETACHENT sans
/// jamais supprimer du `ModelContext` : c'est a `EditorController` d'appeler
/// `ModelContext.delete(_:)` sur les `Block` de structure (`columnList`/`column`) qui
/// deviennent orphelins a l'issue d'une dissolution -- meme motif que la purge
/// documentee par `EditorControllerDeletionPurgeTests`.
@MainActor
public enum ColumnStructure {
    /// Maximum de colonnes cote a cote (docs/10, artboard J : "Maximum 4 colonnes").
    public static let maxColumns = 4

    /// Une colonne accepte tout type de bloc SAUF un tableau (docs/10, regle du
    /// design : "Une colonne accepte tout sauf un tableau" -- une grille imbriquee dans
    /// une colonne etroite n'a pas de rendu sense aujourd'hui).
    public static func canEnterColumn(_ block: Block) -> Bool {
        block.type != .table
    }

    // MARK: - Fractions de largeur (voir `ColumnFractions`, `SlateUI`, pure/testee)

    /// Fractions de largeur des colonnes de `columnList`, dans l'ordre de ses enfants
    /// (`order` croissant). Repartition EGALE si une colonne n'a jamais ete
    /// redimensionnee (`columnWidthRatio == nil`) -- coherent avec `ColumnFractions.
    /// normalized(_:)`, qui repartit deja equitablement une somme nulle/invalide.
    public static func widthFractions(for columnList: Block) -> [CGFloat] {
        let columns = BlockOrdering.children(of: columnList)
        guard !columns.isEmpty else { return [] }
        let equalShare = 1.0 / Double(columns.count)
        let raw = columns.map { CGFloat($0.attributes.columnWidthRatio ?? equalShare) }
        return ColumnFractions.normalized(raw)
    }

    /// Ecrit `fractions` (normalisees) sur chaque colonne de `columnList`, dans l'ordre
    /// -- appele apres un glissement du separateur (`ColumnsBlockView`).
    public static func applyFractions(_ fractions: [CGFloat], to columnList: Block) {
        let columns = BlockOrdering.children(of: columnList)
        let normalized = ColumnFractions.normalized(fractions)
        for (index, column) in columns.enumerated() where normalized.indices.contains(index) {
            column.attributes.columnWidthRatio = Double(normalized[index])
        }
    }

    // MARK: - Creation (depot lateral, docs/10 artboard I "Depot lateral -> colonne")

    /// Cree une mise en colonnes de 2 colonnes a partir de deux blocs : `target` (le
    /// bloc survole, dont le tiers lateral a recu le depot) et `moved` (le bloc
    /// deplace). Le `columnList` resultant prend EXACTEMENT la place de `target` parmi
    /// ses anciens freres (meme `parent`/`note`/position) ; `target` GARDE son propre
    /// sous-arbre (ses enfants le suivent dans sa colonne, ce n'est pas une
    /// suppression). `moved` est detache de son emplacement d'origine par cette
    /// fonction elle-meme -- l'appelant n'a pas a le faire au prealable.
    ///
    /// `edge == .trailing` place `target` a gauche et `moved` a droite (depot sur le
    /// bord droit de `target`) ; `.leading` inverse (depot sur son bord gauche).
    /// N'importe quel autre `Edge` est traite comme `.trailing` (les seuls cas lateraux
    /// reels sont `.leading`/`.trailing`, voir `BlockContainer.dropEdge`).
    @discardableResult
    public static func createColumns(target: Block, moved: Block, edge: Edge) -> Block {
        let note = target.note

        let columnList = Block(type: .columnList, note: note)
        let firstColumn = Block(type: .column, note: note)
        let secondColumn = Block(type: .column, note: note)
        firstColumn.parent = columnList
        secondColumn.parent = columnList
        firstColumn.order = 0
        secondColumn.order = 1
        firstColumn.attributes.columnWidthRatio = 0.5
        secondColumn.attributes.columnWidthRatio = 0.5
        columnList.children = [firstColumn, secondColumn]

        // Place `columnList` juste APRES `target` dans sa fratrie ACTUELLE (primitive
        // deja eprouvee, invalide deja le cache elle-meme), puis detache `target` de
        // cette meme fratrie : le retrait de `target` fait glisser `columnList`
        // EXACTEMENT a la position qu'il occupait, sans reimplementer cette algebre.
        BlockOrdering.insert(columnList, after: target)
        BlockOrdering.detachPreservingChildren(target)
        BlockOrdering.invalidateCache(for: note)
        BlockOrdering.detachPreservingChildren(moved)
        BlockOrdering.invalidateCache(for: note)

        let (leftBlock, rightBlock) = edge == .leading ? (moved, target) : (target, moved)
        place(leftBlock, asOnlyChildOf: firstColumn, note: note)
        place(rightBlock, asOnlyChildOf: secondColumn, note: note)
        BlockOrdering.invalidateCache(for: note)
        return columnList
    }

    /// Ajoute `moved` comme NOUVELLE colonne de `columnList`, a l'index `index` (0 =
    /// premiere position). Refuse (`false`, sans effet) si `columnList` n'est pas du bon
    /// type, si `moved` est un tableau (voir `canEnterColumn(_:)`), ou si
    /// `columnList` compte deja `maxColumns` colonnes. Redistribue les fractions
    /// EGALEMENT entre toutes les colonnes -- meme choix assume que
    /// `ColumnFractions.removing(_:at:)` (aucune information sur laquelle des colonnes
    /// existantes devrait "ceder" de la place a la nouvelle).
    @discardableResult
    public static func addColumn(moved: Block, to columnList: Block, at index: Int) -> Bool {
        guard columnList.type == .columnList, canEnterColumn(moved) else { return false }
        let columns = BlockOrdering.children(of: columnList)
        guard columns.count < maxColumns else { return false }

        BlockOrdering.detachPreservingChildren(moved)
        BlockOrdering.invalidateCache(for: columnList.note)
        let newColumn = Block(type: .column, note: columnList.note)
        newColumn.parent = columnList
        place(moved, asOnlyChildOf: newColumn, note: columnList.note)

        var updated = columns
        let insertIndex = min(max(0, index), updated.count)
        updated.insert(newColumn, at: insertIndex)
        for (position, column) in updated.enumerated() { column.order = position }
        columnList.children = updated

        let equalShare = 1.0 / Double(updated.count)
        applyFractions(Array(repeating: CGFloat(equalShare), count: updated.count), to: columnList)
        BlockOrdering.invalidateCache(for: columnList.note)
        return true
    }

    // MARK: - Dissolution (docs/10 : "Retirer le dernier bloc d'une colonne dissout la
    // structure proprement")

    /// A appeler apres avoir retire un bloc du contenu d'une colonne (deplacement
    /// ailleurs, suppression) : nettoie `columnList` en consequence.
    /// - Toute colonne DEVENUE VIDE est elle-meme retiree (sa part de largeur
    ///   redistribuee entre les colonnes restantes, voir `ColumnFractions.removing(_:at:)`).
    /// - S'il ne reste alors QU'UNE SEULE colonne, la structure ENTIERE est dissoute :
    ///   le contenu de cette derniere colonne REMONTE exactement a la place qu'occupait
    ///   `columnList` (meme `parent`/`note`/position parmi ses anciens freres).
    ///
    /// Retourne les `Block` de structure (`columnList` lui-meme et toute `column`
    /// devenue orpheline) devenus orphelins par cette operation -- a purger du
    /// `ModelContext` par l'appelant (voir la documentation de tete de fichier).
    @discardableResult
    public static func dissolveIfNeeded(_ columnList: Block) -> [Block] {
        guard columnList.type == .columnList else { return [] }
        var columns = BlockOrdering.children(of: columnList)
        var fractions = widthFractions(for: columnList)
        var orphanedColumns: [Block] = []

        var index = 0
        while index < columns.count {
            guard BlockOrdering.children(of: columns[index]).isEmpty else {
                index += 1
                continue
            }
            let removed = columns.remove(at: index)
            fractions = ColumnFractions.removing(fractions, at: index)
            orphanedColumns.append(removed)
            detach(removed)
        }

        for (position, column) in columns.enumerated() { column.order = position }
        columnList.children = columns
        if columns.count > 1 {
            let normalized = fractions.count == columns.count
                ? fractions
                : Array(repeating: CGFloat(1.0 / Double(columns.count)), count: columns.count)
            applyFractions(normalized, to: columnList)
        }
        BlockOrdering.invalidateCache(for: columnList.note)

        guard columns.count <= 1 else { return orphanedColumns }
        let dissolved = dissolve(columnList, remainingColumn: columns.first)
        return orphanedColumns + dissolved
    }

    /// Dissout `columnList` entierement : reinsere CHAQUE bloc du contenu de
    /// `remainingColumn` (s'il en a), DANS L'ORDRE, juste apres `columnList` (via la
    /// meme primitive eprouvee que `createColumns`), puis detache `columnList` --
    /// desormais entoure de ce contenu promu -- de cette fratrie. Le resultat NET est
    /// que le contenu promu occupe exactement l'ancienne position de `columnList`.
    /// Retourne les blocs de structure devenus orphelins (`columnList`, et
    /// `remainingColumn` s'il existait).
    private static func dissolve(_ columnList: Block, remainingColumn: Block?) -> [Block] {
        let note = columnList.note
        let promoted = remainingColumn.map { BlockOrdering.children(of: $0) } ?? []

        var anchor = columnList
        for child in promoted {
            BlockOrdering.detachPreservingChildren(child)
            BlockOrdering.invalidateCache(for: note)
            BlockOrdering.insert(child, after: anchor)
            anchor = child
        }

        BlockOrdering.detachPreservingChildren(columnList)
        BlockOrdering.invalidateCache(for: note)

        var orphaned: [Block] = [columnList]
        if let remainingColumn {
            detach(remainingColumn)
            orphaned.append(remainingColumn)
        }
        detach(columnList)
        return orphaned
    }

    // MARK: - Aides structurelles

    private static func place(_ block: Block, asOnlyChildOf column: Block, note: Note?) {
        block.parent = column
        block.note = note
        block.order = 0
        column.children = [block]
    }

    private static func detach(_ block: Block) {
        block.parent = nil
        block.note = nil
        block.children = []
    }
}
