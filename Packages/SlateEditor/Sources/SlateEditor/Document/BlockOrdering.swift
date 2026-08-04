import Foundation
import SlateModel

/// Fonctions pures de tri et de navigation dans l'arbre de blocs d'une `Note`.
///
/// SwiftData n'a pas de relation ordonnee (voir `Block.order` dans `SlateModel`) :
/// aucune lecture ne doit se fier a l'ordre d'insertion de `note.blocks` ou de
/// `block.children`, toujours trier explicitement par `order`. Ce type centralise ce
/// tri pour que le routeur de bloc (`NoteDocumentView`/`BlockTreeView`) n'ait jamais a
/// le refaire lui-meme, et pour que la regle reste testable independamment de SwiftUI.
public enum BlockOrdering {
    /// Trie une liste de blocs freres par `order` croissant.
    public static func sortedByOrder(_ blocks: [Block]) -> [Block] {
        blocks.sorted { $0.order < $1.order }
    }

    /// Blocs racine d'une note (sans parent), tries par `order`.
    public static func topLevelBlocks(of note: Note) -> [Block] {
        sortedByOrder((note.blocks ?? []).filter { $0.parent == nil })
    }

    /// Blocs enfants directs d'un bloc, tries par `order`.
    public static func children(of block: Block) -> [Block] {
        sortedByOrder(block.children ?? [])
    }

    /// Profondeur d'imbrication d'un bloc : nombre d'ancetres jusqu'a la racine de la
    /// note (0 pour un bloc racine). Utilise pour l'indentation visuelle des items de
    /// liste (et, plus tard, des colonnes).
    public static func indentLevel(of block: Block) -> Int {
        var level = 0
        var current = block.parent
        while let parent = current {
            level += 1
            current = parent.parent
        }
        return level
    }

    /// Rang 1-based d'un item de liste numerotee au sein d'une serie CONTIGUE de freres
    /// de type `.numberedList` : la numerotation redemarre a 1 si elle est interrompue
    /// par un bloc frere d'un autre type (comportement attendu d'un editeur de blocs :
    /// deux listes numerotees separees par un paragraphe repartent chacune a 1).
    ///
    /// `siblings` doit etre l'ensemble des freres directs du bloc (memes `parent`),
    /// dans n'importe quel ordre : la fonction retrie elle-meme par `order`.
    public static func numberedListRank(of block: Block, among siblings: [Block]) -> Int {
        let ordered = sortedByOrder(siblings)
        guard let index = ordered.firstIndex(where: { $0.id == block.id }) else { return 1 }

        var rank = 1
        var cursor = index - 1
        while cursor >= 0, ordered[cursor].type == .numberedList {
            rank += 1
            cursor -= 1
        }
        return rank
    }
}
