import Foundation
import SlateModel

/// Mutations structurelles d'un tableau (docs/08_blocs_speciaux.md, "Tableaux") :
/// ajout/suppression de ligne/colonne, largeur de colonne. Delegue l'integrite de la
/// grille a `Block.TableStructureError`/`Block+Table.swift` (`SlateModel`) -- ce fichier
/// se contente d'adapter ses erreurs en decisions d'edition (voir "Dissolution du
/// tableau" ci-dessous) et de tenir les DEUX garanties que le modele documente
/// explicitement comme etant a la charge de l'appelant :
///
/// 1. **Purge du `ModelContext`.** `Block.removeTableRow(at:)`/`removeTableColumn(at:)`
///    detachent le(s) bloc(s) retire(s) du graphe EN MEMOIRE mais ne les suppriment
///    jamais eux-memes d'un `ModelContext` -- documente explicitement sur les deux
///    fonctions. Chaque suppression ci-dessous appelle donc `ModelContext.delete(_:)`
///    sur le(s) bloc retourne(s) : sans cet appel, la ligne/colonne "disparue" resterait
///    un enregistrement orphelin persiste indefiniment (jamais purge par `save()` seul).
/// 2. **Invalidation du cache d'ordre.** Toute mutation ci-dessous modifie la structure
///    de l'arbre de blocs (ajout/retrait d'enfants) SANS passer par
///    `BlockOrdering.insert`/`remove` (qui l'invalideraient eux-memes) : voir
///    `BlockOrderingCache.swift`, "la seule regle qui compte pour la SURETE de ce
///    cache". Chaque methode invalide donc explicitement `BlockOrdering.orderCache`
///    pour la note du tableau avant de persister.
///
/// ## Dissolution du tableau (refus du modele sur la derniere ligne/colonne)
/// `Block.removeTableRow`/`removeTableColumn` REFUSENT de supprimer la derniere
/// ligne/colonne (`TableStructureError.cannotRemoveLastRow`/`cannotRemoveLastColumn`) --
/// choix documente du modele : decider ce que devient un tableau qu'on vide entierement
/// est une decision d'EDITEUR, pas de donnees. La decision ici : dans ce cas precis, le
/// bloc `table` ENTIER est supprime (`EditorController.deleteBlock(_:)`, qui sait deja
/// traiter un `table` sans promouvoir ses lignes -- voir sa documentation) plutot que de
/// laisser l'operation echouer silencieusement.
@MainActor
extension EditorController {
    // MARK: - Lignes

    /// Insere une nouvelle ligne (autant de cellules que les lignes existantes, texte
    /// vide) a `index` (par defaut, en derniere position). Sans effet si `table` n'est
    /// pas un `.table` ou si `index` est hors bornes (`Block.TableStructureError`,
    /// silencieusement ignoree : l'appelant UI ne devrait jamais fournir un index
    /// invalide, voir `TableBlockContentView`).
    public func insertTableRow(in table: Block, at index: Int? = nil) {
        guard (try? table.insertTableRow(at: index)) != nil else { return }
        BlockOrdering.invalidateCache(for: table.note)
        persistStructuralChange()
    }

    /// Retire la ligne a `index`. Si c'est la DERNIERE ligne du tableau, supprime le
    /// tableau entier (voir la documentation de tete de fichier, "Dissolution du
    /// tableau") plutot que de refuser silencieusement.
    public func removeTableRow(_ table: Block, at index: Int) {
        do {
            let removed = try table.removeTableRow(at: index)
            modelContext?.delete(removed)
            BlockOrdering.invalidateCache(for: table.note)
            persistStructuralChange()
        } catch Block.TableStructureError.cannotRemoveLastRow {
            dissolveTable(table)
        } catch {
            // `rowIndexOutOfRange`/`notATable` : l'appelant UI garantit deja un index et
            // un type valides (voir `TableBlockContentView`), aucun effet defensif de
            // plus a apporter ici.
        }
    }

    // MARK: - Colonnes

    /// Insere une nouvelle colonne (une cellule vide dans chaque ligne) a `index` (par
    /// defaut, en derniere position). Meme garde silencieuse que `insertTableRow(in:at:)`.
    public func insertTableColumn(in table: Block, at index: Int? = nil) {
        guard (try? table.insertTableColumn(at: index)) != nil else { return }
        BlockOrdering.invalidateCache(for: table.note)
        persistStructuralChange()
    }

    /// Retire la colonne a `index` dans toutes les lignes. Si c'est la DERNIERE colonne,
    /// supprime le tableau entier -- meme decision que `removeTableRow(_:at:)`.
    public func removeTableColumn(_ table: Block, at index: Int) {
        do {
            let removedCells = try table.removeTableColumn(at: index)
            for cell in removedCells { modelContext?.delete(cell) }
            BlockOrdering.invalidateCache(for: table.note)
            persistStructuralChange()
        } catch Block.TableStructureError.cannotRemoveLastColumn {
            dissolveTable(table)
        } catch {
            // `columnIndexOutOfRange`/`notATable` : meme remarque que ci-dessus.
        }
    }

    /// Supprime le `table` ENTIER (voir la documentation de tete de fichier,
    /// "Dissolution du tableau") : `deleteBlock(_:)` gere deja completement ce cas pour
    /// un `.table` (detachement `removeSubtree` PUIS `ModelContext.delete(_:)`, voir sa
    /// documentation) -- meme chemin que le menu de bloc generique ("Supprimer" sur un
    /// tableau), pour ne jamais avoir deux implementations de la meme garantie
    /// d'absence d'orphelin. `persistStructuralChange()` est deja appele par
    /// `deleteBlock(_:)`, inutile de le refaire ici.
    private func dissolveTable(_ table: Block) {
        deleteBlock(table)
    }

    // MARK: - Contenu d'une cellule (texte simple, voir `TableBlockContentView`)

    /// Reecrit le texte d'une `tableCell` depuis une `String` simple (docs/08 : "texte
    /// simple d'abord suffit", texte riche en cellule remis a plus tard). Persiste comme
    /// toute autre operation structurelle de ce fichier -- une cellule de tableau n'a pas
    /// le debounce dedie de `RichTextBlockView`/`BlockSaveDebouncer` (reserve au texte
    /// riche d'un bloc, hors perimetre ici).
    public func setTableCellText(_ text: String, in cell: Block) {
        guard cell.type == .tableCell else { return }
        cell.text = RichText(plainText: text)
        persistStructuralChange()
    }

    // MARK: - Largeur de colonne (redimensionnement, artboard H)

    /// Applique une largeur (en points) a la colonne `index`, sur toutes les lignes.
    /// `nil` revient a la largeur naturelle/auto. Sans effet si `table` n'est pas un
    /// `.table` ou si `index` est hors bornes.
    public func setTableColumnWidth(_ width: Double?, forColumnAt index: Int, in table: Block) {
        do {
            try table.setTableColumnWidth(width, forColumnAt: index)
            persistStructuralChange()
        } catch {
            // `columnIndexOutOfRange`/`notATable` : meme remarque que ci-dessus.
        }
    }
}
