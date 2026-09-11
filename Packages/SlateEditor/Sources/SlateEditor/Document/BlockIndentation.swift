import Foundation
import SlateModel

/// Logique PURE (aucune dependance AppKit, aucun `ModelContext`) de l'indentation d'un
/// item de liste au clavier (Tab/Maj+Tab -- docs/08_blocs_speciaux.md, "Imbrication").
/// Meme principe que `BlockLifecycle`/`BlockOperations` : opere directement sur le
/// graphe `Block`/`Note` deja en memoire, entierement testable sans `NSTextView`.
///
/// ## Restriction aux items de liste
/// Seuls `bulletedList`/`numberedList`/`todo` peuvent etre indentes/desindentes par ce
/// geste -- indenter un paragraphe ou un titre n'a pas de sens dans le vocabulaire
/// actuel de l'editeur (un paragraphe imbrique sous un autre paragraphe ne se
/// distinguerait visuellement de rien). Sans effet (`false`) pour tout autre type.
///
/// ## Le sous-arbre suit intact
/// Contrairement a `BlockOrdering.remove(_:)` (suppression d'un bloc, ses enfants sont
/// PROMUS a sa place), indenter/desindenter un item ne doit JAMAIS dissoudre ses propres
/// sous-items : `indent(_:)`/`outdent(_:)` deplacent `block` ET tout son sous-arbre
/// ensemble, via `BlockOrdering.detachPreservingChildren(_:)` +
/// `attachAsLastChild(_:of:)`/`attachAsSibling(_:after:)` (voir leur documentation dans
/// `BlockOrdering.swift`, seul fichier a pouvoir les implementer -- ils touchent des
/// helpers prives de ce type).
@MainActor
public enum BlockIndentation {
    /// Tab sur un item de liste : le fait passer enfant du FRERE DIRECT qui le precede
    /// immediatement (comportement Notion/Notes standard). Sans effet (`false`) si
    /// `block` n'est pas un item de liste, ou s'il est deja le PREMIER de sa fratrie
    /// (aucun frere precedent sous lequel s'imbriquer).
    @discardableResult
    public static func indent(_ block: Block) -> Bool {
        guard isListType(block.type) else { return false }
        let siblings = BlockOrdering.siblings(of: block)
        guard let index = siblings.firstIndex(where: { $0.id == block.id }), index > 0 else { return false }
        let newParent = siblings[index - 1]

        BlockOrdering.detachPreservingChildren(block)
        BlockOrdering.attachAsLastChild(block, of: newParent)
        return true
    }

    /// Maj+Tab sur un item de liste : le fait remonter d'un niveau, juste APRES son
    /// ancien parent (au meme niveau que lui). Sans effet (`false`) si `block` n'est pas
    /// un item de liste, ou s'il est deja au niveau RACINE (aucun parent dont sortir).
    @discardableResult
    public static func outdent(_ block: Block) -> Bool {
        guard isListType(block.type) else { return false }
        guard let parent = block.parent else { return false }

        BlockOrdering.detachPreservingChildren(block)
        BlockOrdering.attachAsSibling(block, after: parent)
        return true
    }

    private static func isListType(_ type: BlockType) -> Bool {
        type == .bulletedList || type == .numberedList || type == .todo
    }
}
