import CoreGraphics
import Foundation
import SlateModel
import SlateUI

/// Selection multi-blocs (docs/05_editeur_blocs.md, sous-etape 5.6) : extension d'un
/// clic + Maj, d'un glisser, ou de Maj + fleche haut/bas ; operations en lot
/// (suppression, deplacement, conversion) sur la plage courante. Separe de
/// `EditorController.swift` (qui porte le cycle de vie de base -- 5.3/5.4/5.5) pour
/// rester sous la limite de longueur de fichier de `CLAUDE.md` §5, sans que cela change
/// quoi que ce soit du point de vue de l'appelant : `EditorController` reste UN SEUL
/// type, cette extension n'ajoute aucune nouvelle surface publique qui lui serait
/// propre.
extension EditorController {
    // MARK: - Extension (clic + Maj, Maj + fleche -- spec E4 "GALERIE D'ETATS" :
    // "clic + Maj etend la selection du bloc ancre jusqu'au bloc clique")

    /// Etend la plage de selection courante jusqu'a `block` (clic + Maj). Si aucune
    /// selection n'est active, l'ANCRE devient le bloc le plus recemment
    /// focalise/selectionne (`focusedBlockID` puis `selectedBlockID`), ou `block`
    /// lui-meme en dernier recours (premier clic + Maj de la session, sans point de
    /// depart connu) -- reproduit le comportement usuel d'une extension de selection de
    /// texte (`NSTextView`) applique aux blocs.
    public func extendSelection(to block: Block) {
        let anchorID = blockSelectionRange?.anchorBlockID ?? focusedBlockID ?? selectedBlockID ?? block.id
        focusedBlockID = nil
        blockSelectionRange = BlockSelectionRange(anchorBlockID: anchorID, focusBlockID: block.id)
        pendingCaretRequest = nil
    }

    /// Etend la plage de selection courante d'UN pas dans l'ordre d'affichage reel
    /// (Maj + fleche haut/bas -- voir `BlockSelectionOperations.extendingByStep`).
    /// `block` est le bloc D'OU partir si aucune plage n'est deja active (le bloc en
    /// cours d'edition au moment de l'appui). `false` sans effet si aucun bloc n'existe
    /// dans cette direction (bord du document) : l'appelant (`RichTextEditingTextView`)
    /// doit alors laisser le comportement natif de selection de texte intra-bloc
    /// s'executer.
    @discardableResult
    public func extendSelectionVertically(_ direction: BlockSelectionDirection, from block: Block) -> Bool {
        guard let nextRange = BlockSelectionOperations.extendingByStep(
            from: blockSelectionRange, fallbackBlockID: block.id, direction: direction, in: note
        ) else {
            return false
        }
        focusedBlockID = nil
        blockSelectionRange = nextRange
        pendingCaretRequest = nil
        return true
    }

    // MARK: - Glisser (spec E4 : "glisser")
    //
    // Distinct du glisser de DEPLACEMENT de la poignee (Phase 10, `BlockHandle.
    // draggable(_:)`, `SlateUI`) : celui-ci est une session de glisser-depose native
    // (`Transferable`/`NSItemProvider`), capturee EXCLUSIVEMENT par le petit bouton de
    // la poignee -- un `DragGesture` SwiftUI attache par ailleurs (ici, sur la zone de
    // CONTENU de chaque bloc, voir `BlockTreeView`) ne partage aucun mecanisme de
    // reconnaissance de geste avec `.draggable(_:)` et ne peut donc jamais s'y
    // substituer ni le court-circuiter. La frontiere de bloc N'EST PAS franchie tant
    // que le point courant du glisser reste dans le bloc ou il a commence (spec E4 :
    // "la selection de texte reste locale au bloc tant qu'elle ne franchit pas la
    // frontiere") -- voir `continueBlockRangeDrag(pointerLocation:)`.

    /// Debut d'un glisser potentiel de selection, dans le bloc `block` (ou le geste a
    /// commence). N'active PAS encore de plage : voir `continueBlockRangeDrag(pointerLocation:)`.
    public func beginBlockRangeDrag(at block: Block) {
        dragRangeAnchorBlockID = block.id
    }

    /// A appeler a chaque mise a jour de position pendant le glisser (`DragGesture.
    /// onChanged`), `pointerLocation` dans la MEME `coordinateSpace` que `blockFrames`
    /// (voir `updateBlockFrames(_:)`). N'active la plage de selection QUE si le point
    /// courant est desormais dans un bloc DIFFERENT de l'ancre du glisser (frontiere
    /// franchie), ou si une plage est deja active (le glisser peut aussi bien retrer
    /// vers le bloc d'origine, ce qui reduit la plage a un seul bloc). Sans effet si
    /// aucun glisser n'a ete demarre (`beginBlockRangeDrag(at:)` jamais appele) ou si
    /// aucun bloc connu ne couvre `pointerLocation`.
    public func continueBlockRangeDrag(pointerLocation: CGPoint) {
        guard let anchorID = dragRangeAnchorBlockID, let targetID = blockID(at: pointerLocation) else { return }
        guard targetID != anchorID || blockSelectionRange != nil else { return }
        focusedBlockID = nil
        blockSelectionRange = BlockSelectionRange(anchorBlockID: anchorID, focusBlockID: targetID)
        pendingCaretRequest = nil
    }

    /// Fin du geste de glisser (`DragGesture.onEnded`) : la plage de selection
    /// eventuellement etablie PERSISTE (l'utilisateur relache la souris sur sa
    /// selection), seul l'etat interne de suivi du glisser lui-meme est nettoye.
    public func endBlockRangeDrag() {
        dragRangeAnchorBlockID = nil
    }

    /// Alimente `blockFrames` (voir sa documentation) -- appele par `NoteDocumentView`
    /// via `.onPreferenceChange(BlockFramePreferenceKey.self)` a chaque changement de
    /// mise en page. Idempotent, sans effet observable si la valeur n'a pas change.
    public func updateBlockFrames(_ frames: [UUID: CGRect]) {
        blockFrames = frames
    }

    /// Resout quel bloc contient `point`, en ne comparant que l'ORDONNEE : chaque bloc
    /// s'etend sur toute la largeur de la colonne de texte (voir `EditorContentColumn`),
    /// seule la position verticale distingue un bloc d'un autre pendant un glisser.
    private func blockID(at point: CGPoint) -> UUID? {
        blockFrames.first { $0.value.minY <= point.y && point.y < $0.value.maxY }?.key
    }

    // MARK: - Operations en lot (voir `BlockSelectionOperations` pour la logique pure
    // et les decisions documentees)

    /// Action "Supprimer" du menu de bloc QUAND `blockSelectionRange` couvre PLUSIEURS
    /// blocs (sinon `deleteBlock(_:)` reste le chemin a utiliser -- comportement
    /// inchange depuis la sous-etape 5.4). Selectionne le meme voisin de secours que
    /// `deleteBlock(_:)` : le bloc suivant le DERNIER bloc de la plage dans l'ordre
    /// d'affichage, sinon celui qui precede son PREMIER bloc, sinon le premier bloc
    /// restant de la note.
    public func deleteSelectionRange() {
        guard let range = blockSelectionRange else { return }
        let ordered = BlockSelectionOperations.orderedBlocks(of: range, in: note)
        guard let firstBlock = ordered.first, let lastBlock = ordered.last else { return }
        let neighborID = BlockOrdering.block(after: lastBlock)?.id ?? BlockOrdering.block(before: firstBlock)?.id

        if let focusedBlockID, ordered.contains(where: { $0.id == focusedBlockID }) {
            self.focusedBlockID = nil
        }

        BlockSelectionOperations.deleteRange(range, in: note)
        // Meme purge du store que dans `deleteBlock(_:)`, appliquee a tout le lot :
        // `deleteRange` detache sans supprimer. Les enfants hors plage ont ete promus,
        // ils ne sont donc pas emportes par la cascade.
        for block in ordered {
            modelContext?.delete(block)
        }

        let fallbackID = neighborID ?? BlockOrdering.flattenedBlocks(of: note).first?.id
        blockSelectionRange = fallbackID.map { BlockSelectionRange(single: $0) }
        pendingCaretRequest = nil
        persistStructuralChange()
    }

    /// Action "Deplacer vers le haut" du menu de bloc pour une plage de PLUSIEURS blocs
    /// (voir `BlockSelectionOperations.moveRangeUp(_:in:)` pour la portee -- freres
    /// contigus de meme niveau uniquement). `false` sans effet si la plage n'est pas
    /// deplacable dans cette direction.
    @discardableResult
    public func moveSelectionRangeUp() -> Bool {
        guard let range = blockSelectionRange, BlockSelectionOperations.moveRangeUp(range, in: note) else {
            return false
        }
        persistStructuralChange()
        return true
    }

    /// Symmetrique de `moveSelectionRangeUp()` : un cran vers le bas.
    @discardableResult
    public func moveSelectionRangeDown() -> Bool {
        guard let range = blockSelectionRange, BlockSelectionOperations.moveRangeDown(range, in: note) else {
            return false
        }
        persistStructuralChange()
        return true
    }

    /// La plage courante peut-elle se deplacer d'un cran vers le haut/le bas ? Utilise
    /// par le menu de bloc pour desactiver les entrees correspondantes plutot que de
    /// laisser un controle qui semble actionnable sans effet (meme regle d'honnetete
    /// d'interface que `BlockMenuView.canMoveUp`/`canMoveDown`).
    public func canMoveSelectionRangeUp() -> Bool {
        guard let range = blockSelectionRange else { return false }
        return BlockSelectionOperations.canMoveRange(range, in: note, by: -1)
    }

    public func canMoveSelectionRangeDown() -> Bool {
        guard let range = blockSelectionRange else { return false }
        return BlockSelectionOperations.canMoveRange(range, in: note, by: 1)
    }

    /// Action "Convertir en..." du menu de bloc pour une plage de PLUSIEURS blocs (voir
    /// `BlockSelectionOperations.convertRange(_:to:in:)` pour le sort des blocs non
    /// convertibles -- ignores, pas bloquants). La plage reste SELECTIONNEE apres
    /// conversion, coherente avec `convertBlock(_:to:)`.
    public func convertSelectionRange(to newType: BlockType) {
        guard let range = blockSelectionRange else { return }
        BlockSelectionOperations.convertRange(range, to: newType, in: note)
        pendingCaretRequest = nil
        persistStructuralChange()
    }

    /// `BlockConversion.convertibleTypes` proposes au sous-menu "Convertir en..." pour
    /// la plage courante, ou vide si AUCUN bloc de la plage n'accepte de conversion
    /// (voir `BlockSelectionOperations.hasAnyConvertibleBlock(in:note:)`) -- meme regle
    /// d'honnetete d'interface que `BlockConversion.availableTargets(for:)` pour un
    /// bloc unique.
    public func availableConversionTargetsForSelectionRange() -> [BlockType] {
        guard let range = blockSelectionRange,
              BlockSelectionOperations.hasAnyConvertibleBlock(in: range, note: note) else {
            return []
        }
        return BlockConversion.convertibleTypes
    }

    /// Association `blockID -> SlateBlockRangePosition` de la plage COURANTE, calculee
    /// UNE SEULE FOIS par rendu complet de l'arbre (voir `NoteDocumentView`) et enfilee
    /// jusqu'a chaque `BlockTreeView` -- jamais recalculee bloc par bloc (ce qui
    /// couterait O(n) par bloc, donc O(n^2) pour tout le document, sur une note de 200+
    /// blocs). Vide si aucune selection n'est active.
    public func selectionRangePositions() -> [UUID: SlateBlockRangePosition] {
        guard let range = blockSelectionRange else { return [:] }
        let ids = BlockSelectionOperations.orderedBlockIDs(of: range, in: note)
        return BlockSelectionOperations.rangePositions(forOrderedIDs: ids)
    }
}
