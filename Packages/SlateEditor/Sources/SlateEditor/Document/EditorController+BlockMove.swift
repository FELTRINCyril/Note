import Foundation
import SlateModel

/// Equivalent clavier OBLIGATOIRE du glisser-depose de reordonnancement (Phase 10,
/// docs/10_dragdrop_colonnes.md, artboard I : "Ctrl+Cmd + fleches haut/bas deplacent un
/// bloc, avec une annonce VoiceOver du type 'deplace en position 2 sur 5'"). Reutilise
/// EXCLUSIVEMENT `BlockOperations.moveUp(_:)`/`moveDown(_:)` (bloc unique) et
/// `BlockSelectionOperations.moveRangeUp(_:in:)`/`moveRangeDown(_:in:)` (plage) -- deja
/// eprouves par leurs propres tests (`BlockOperationsTests`/
/// `BlockSelectionOperationsTests`) -- cette extension n'ajoute que le calcul de
/// l'annonce et la persistance, jamais une seconde implementation du deplacement
/// lui-meme.
///
/// Separe de `EditorController+BlockMenu.swift` (qui porte deja `moveBlockUp(_:)`/
/// `moveBlockDown(_:)`, SANS annonce -- utilises par le menu de bloc, ou un simple
/// changement visuel suffit) : le clavier, lui, DOIT annoncer explicitement le
/// deplacement pour VoiceOver, une info que le menu de bloc n'a pas besoin de produire.
extension EditorController {
    /// Deplace `block` seul d'un cran vers le haut (Ctrl+Cmd+fleche haut sur un bloc
    /// SELECTIONNE SEUL). Retourne l'annonce VoiceOver a poster ("deplace en position X
    /// sur Y") si le deplacement a eu lieu, `nil` sans effet si `block` etait deja en
    /// tete de sa fratrie.
    @discardableResult
    public func moveBlockUpWithAnnouncement(_ block: Block) -> String? {
        guard BlockOperations.moveUp(block) else { return nil }
        persistStructuralChange()
        return Self.positionAnnouncement(for: block)
    }

    /// Symmetrique de `moveBlockUpWithAnnouncement(_:)` : un cran vers le bas.
    @discardableResult
    public func moveBlockDownWithAnnouncement(_ block: Block) -> String? {
        guard BlockOperations.moveDown(block) else { return nil }
        persistStructuralChange()
        return Self.positionAnnouncement(for: block)
    }

    /// Deplace la plage de blocs SELECTIONNES d'un cran vers le haut (voir
    /// `BlockSelectionOperations.moveRangeUp(_:in:)` pour la portee -- freres contigus
    /// de meme niveau uniquement). `nil` sans effet si aucune plage n'est active ou si
    /// le deplacement est refuse.
    @discardableResult
    public func moveSelectionRangeUpWithAnnouncement() -> String? {
        guard let range = blockSelectionRange, BlockSelectionOperations.moveRangeUp(range, in: note) else {
            return nil
        }
        persistStructuralChange()
        return Self.rangeAnnouncement(for: range, in: note)
    }

    /// Symmetrique de `moveSelectionRangeUpWithAnnouncement()` : un cran vers le bas.
    @discardableResult
    public func moveSelectionRangeDownWithAnnouncement() -> String? {
        guard let range = blockSelectionRange, BlockSelectionOperations.moveRangeDown(range, in: note) else {
            return nil
        }
        persistStructuralChange()
        return Self.rangeAnnouncement(for: range, in: note)
    }

    /// "Deplace en position X sur Y" pour un bloc UNIQUE : X = son rang 1-based parmi
    /// ses freres ACTUELS (apres le deplacement), Y = leur nombre total.
    private static func positionAnnouncement(for block: Block) -> String {
        let siblings = BlockOrdering.siblings(of: block)
        let position = (siblings.firstIndex(where: { $0.id == block.id }) ?? 0) + 1
        return EditorStrings.blockMoveAccessibilityAnnouncement(position: position, total: siblings.count)
    }

    /// Meme annonce pour une PLAGE de blocs : position du PREMIER bloc de la plage
    /// parmi ses freres (apres le deplacement), sur leur nombre total -- la plage se
    /// deplace comme un bloc solidaire (voir `BlockSelectionOperations`), sa position
    /// est donc entierement decrite par celle de son premier element.
    private static func rangeAnnouncement(for range: BlockSelectionRange, in note: Note) -> String? {
        guard let first = BlockSelectionOperations.orderedBlocks(of: range, in: note).first else { return nil }
        return positionAnnouncement(for: first)
    }
}
