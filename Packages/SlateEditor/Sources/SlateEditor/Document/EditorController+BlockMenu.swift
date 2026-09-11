import Foundation
import SlateModel
import SwiftData

// Actions du menu de bloc (poignee `...`) : dupliquer, supprimer, convertir, deplacer.
//
// Extraites de `EditorController.swift` pour tenir la limite `file_length` de SwiftLint,
// suivant le meme motif que `+Selection`, `+SlashMenu`, `+Formatting`, `+Table` et
// `+SpecialBlocks`. Aucun changement de comportement : seul l'emplacement change.

@MainActor
extension EditorController {
    /// Action "Dupliquer" du menu de bloc (voir `BlockOperations.duplicate(_:)` pour la
    /// copie profonde). Le double est SELECTIONNE (pas focalise en edition) : c'est
    /// l'etat le plus proche du geste "je viens d'agir sur ce bloc precis" sans
    /// pretendre y avoir deja tape du texte.
    public func duplicateBlock(_ block: Block) {
        let copy = BlockOperations.duplicate(block)
        focusedBlockID = nil
        blockSelectionRange = BlockSelectionRange(single: copy.id)
        pendingCaretRequest = nil
        persistStructuralChange()
    }

    /// Action "Supprimer" du menu de bloc (voir `BlockOperations.remove(_:from:)` pour
    /// le sort des enfants et la garantie de non-vacuite de la note). Selectionne le
    /// bloc voisin le plus proche (suivant, sinon precedent, sinon le premier bloc
    /// restant -- necessairement le paragraphe de secours si `block` etait le dernier)
    /// pour que l'utilisateur retrouve immediatement un point d'ancrage clavier.
    public func deleteBlock(_ block: Block) {
        guard let note = block.note else { return }
        let neighborID = BlockOrdering.block(after: block)?.id ?? BlockOrdering.block(before: block)?.id

        // `table` (Phase 8) : structure INTERNE (`tableRow`/`tableCell`), jamais promue
        // au niveau du document -- voir `BlockOperations.removeSubtree(_:from:)`. Cette
        // fonction ne fait que DETACHER `block` : le `delete(_:)` explicite ci-dessous
        // purge reellement le sous-arbre (cascade sur `Block.children`), sinon un
        // tableau supprime par ce menu generique resterait orphelin dans le store --
        // meme garantie que `dissolveTable(_:)` (`EditorController+Table.swift`).
        if block.type == .table {
            BlockOperations.removeSubtree(block, from: note)
        } else {
            BlockOperations.remove(block, from: note)
        }
        // Purge REELLE du store : `BlockOperations` ne fait que detacher, donc sans ce
        // `delete(_:)` le bloc resterait persiste indefiniment (et synchronise vers
        // CloudKit), invisible dans l'interface. La cascade `Block.children` emporte
        // lignes et cellules d'un `table`, mais laisse intacts les enfants d'un bloc
        // ordinaire, deja PROMUS par `BlockOrdering.remove(_:)`. Voir
        // `EditorControllerDeletionPurgeTests`.
        modelContext?.delete(block)

        if focusedBlockID == block.id { focusedBlockID = nil }
        let fallbackID = neighborID ?? BlockOrdering.flattenedBlocks(of: note).first?.id
        blockSelectionRange = fallbackID.map { BlockSelectionRange(single: $0) }
        pendingCaretRequest = nil
        persistStructuralChange()
    }

    /// Action "Convertir en..." du menu de bloc (sous-etape 5.5, voir `BlockConversion`
    /// pour la regle de conservation/abandon des `BlockAttributes`, le texte riche
    /// inchange, et le sort des enfants). Sans effet si `newType` ne fait pas partie de
    /// `BlockConversion.availableTargets(for: block)` -- l'appelant (menu) ne devrait de
    /// toute facon jamais proposer un type hors de cette liste. Le bloc reste
    /// SELECTIONNE apres conversion (pas focalise en edition) : coherent avec
    /// `duplicateBlock(_:)`, la meme action de menu qui ne pretend pas avoir ete
    /// declenchee par une frappe dans le contenu.
    public func convertBlock(_ block: Block, to newType: BlockType) {
        BlockConversion.convert(block, to: newType)
        focusedBlockID = nil
        blockSelectionRange = BlockSelectionRange(single: block.id)
        pendingCaretRequest = nil
        persistStructuralChange()
    }

    /// Action "Deplacer vers le haut" du menu de bloc (voir `BlockOperations.moveUp(_:)`
    /// pour la portee -- freres de meme niveau uniquement). `false` sans effet si
    /// `block` est deja en tete de sa fratrie.
    @discardableResult
    public func moveBlockUp(_ block: Block) -> Bool {
        guard BlockOperations.moveUp(block) else { return false }
        persistStructuralChange()
        return true
    }

    /// Symmetrique de `moveBlockUp(_:)` : un cran vers le bas.
    @discardableResult
    public func moveBlockDown(_ block: Block) -> Bool {
        guard BlockOperations.moveDown(block) else { return false }
        persistStructuralChange()
        return true
    }

    // MARK: - Application interne
}
