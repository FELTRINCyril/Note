import CoreGraphics
import Foundation
import SlateModel
import SlateUI
import SwiftUI

/// Actions sur la mise en colonnes (`BlockType.columnList`/`.column`, Phase 10,
/// docs/10_dragdrop_colonnes.md) : creation par depot lateral, ajout d'une colonne
/// supplementaire, redimensionnement, dissolution -- meme motif de separation que
/// `EditorController+Attachments.swift`/`+SlashMenu.swift`, aucune nouvelle surface
/// publique qui ne soit pas portee par `EditorController` lui-meme.
///
/// ## Purge du store, meme regle que `EditorControllerDeletionPurgeTests`
/// `ColumnStructure` (logique pure) ne fait que DETACHER les blocs de structure
/// (`columnList`/`column`) devenus orphelins -- exactement comme `BlockOrdering`. C'est
/// ICI, avec un `ModelContext` reel, qu'ils sont vraiment retires du store : sans cette
/// purge, chaque colonne dissoute laisserait un `Block` fantome indefiniment persiste
/// (et synchronise vers CloudKit), la meme classe de bug que la revue de Phase 8.
extension EditorController {
    // MARK: - Creation par depot lateral (docs/10, artboard I)

    /// Cree une mise en colonnes en deplacant `moved` sur le bord lateral (`edge`) de
    /// `target`. Sans effet si l'un des deux blocs est un tableau (une colonne
    /// n'accepte pas de tableau, voir `ColumnStructure.canEnterColumn(_:)`), ou s'ils
    /// appartiennent a des notes differentes.
    public func createColumns(moving moved: Block, onto target: Block, edge: Edge) {
        guard target.note?.id == moved.note?.id,
              ColumnStructure.canEnterColumn(target), ColumnStructure.canEnterColumn(moved) else {
            return
        }
        let previousColumnList = moved.parent?.parent
        ColumnStructure.createColumns(target: target, moved: moved, edge: edge)
        dissolveIfEmptied(previousColumnList)
        persistStructuralChange()
    }

    /// Ajoute `moved` comme NOUVELLE colonne de `columnList` (docs/10 : jusqu'a 4
    /// colonnes cote a cote). Sans effet si le maximum est atteint ou si `moved` est un
    /// tableau.
    public func addColumn(moving moved: Block, to columnList: Block, at index: Int) {
        guard columnList.note?.id == moved.note?.id else { return }
        let previousColumnList = moved.parent?.parent
        guard ColumnStructure.addColumn(moved: moved, to: columnList, at: index) else { return }
        dissolveIfEmptied(previousColumnList)
        persistStructuralChange()
    }

    /// Glissement du separateur entre deux colonnes (`ColumnsBlockView`) : ecrit les
    /// nouvelles fractions de largeur. Debounce deliberement absent (comme le reste des
    /// operations structurelles de ce module) : un glissement de separateur reste rare
    /// a l'echelle d'une frappe de texte.
    public func setColumnFractions(_ fractions: [CGFloat], in columnList: Block) {
        guard columnList.type == .columnList else { return }
        ColumnStructure.applyFractions(fractions, to: columnList)
        persistStructuralChange()
    }

    /// A appeler apres tout retrait d'un bloc du contenu d'une colonne (deplacement
    /// ailleurs dans le document, suppression) : nettoie/dissout `columnList` si
    /// necessaire et PURGE reellement du `ModelContext` les blocs de structure devenus
    /// orphelins -- voir la documentation de tete de fichier. Sans effet si
    /// `columnList` est `nil` (le bloc retire ne vivait pas dans une colonne) ou n'est
    /// plus un `columnList` valide.
    func dissolveIfEmptied(_ columnList: Block?) {
        guard let columnList, columnList.type == .columnList else { return }
        let orphaned = ColumnStructure.dissolveIfNeeded(columnList)
        for block in orphaned {
            modelContext?.delete(block)
        }
    }

    // MARK: - Commande "/" (voir `EditorController+SlashMenu.executeSlashCommand`)

    /// Cas particulier `columnList` de la commande "/" : comme `table`, `.columnList`
    /// n'appartient pas a `BlockConversion.convertibleTypes` (pas de `RichText` propre)
    /// et ne peut pas accueillir directement le caret. `block` devient la PREMIERE
    /// colonne (avec tout son contenu propre, texte y compris) d'une structure a 2
    /// colonnes ; la seconde colonne recoit un paragraphe vide qui prend le focus --
    /// point d'entree naturel pour commencer a taper dans la colonne voisine.
    func executeColumnsCommand(in block: Block) {
        let secondColumnContent = Block(type: .paragraph, text: RichText())
        secondColumnContent.note = block.note
        let columnList = ColumnStructure.createColumns(target: block, moved: secondColumnContent, edge: .trailing)
        _ = columnList
        applyFocus(EditorCaretRequest(blockID: secondColumnContent.id, placement: .offset(0)))
    }
}
