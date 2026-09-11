import CoreGraphics
import Foundation
import SlateModel
import SwiftUI
import UniformTypeIdentifiers

/// Glisser-depose de blocs et de fichiers (Phase 10, docs/10_dragdrop_colonnes.md).
///
/// ## Arbitrage SwiftUI natif, pas une gestion custom (voir le rapport de fin de tache)
/// `BlockHandle.draggable(_:)` (`SlateUI`) porte deja une session `Transferable`
/// (`String`, l'UUID du bloc) : ce fichier la RECOIT via `DropDelegate` (protocole
/// LEGACY `View.onDrop(of:delegate:)`, PAS le nouveau `dropDestination(for:action:)`)
/// -- ce dernier ne donne la position du pointeur QU'AU DEPOT final, jamais en continu
/// pendant le survol (`isTargeted` n'est qu'un booleen). Sans position continue,
/// impossible de faire suivre la ligne d'insertion au pointeur (exigence explicite de
/// docs/10) : `DropDelegate.dropUpdated(info:)` est le seul point d'entree SwiftUI qui
/// fournit `info.location` a CHAQUE deplacement du pointeur pendant le survol. Voir
/// `BlockAndFileDropDelegate` (branche vers ce fichier) pour le point d'attache SwiftUI.
///
/// ## Integrite `order`/`parent`/purge (point de vigilance n°1 de docs/10)
/// Toute mutation structurelle passe par les primitives DEJA eprouvees de
/// `BlockOrdering`/`ColumnStructure` -- jamais une nouvelle algebre. Toute dissolution
/// de colonne consecutive a un deplacement SORTANT purge reellement le `ModelContext`
/// via `dissolveIfEmptied(_:)` (`EditorController+Columns.swift`), exactement comme le
/// reste de ce module.
extension EditorController {
    // MARK: - Cycle de vie du glisser (etat consomme par `BlockTreeView`/`NoteDocumentView`)

    /// Bloc(s) attrape(s) par la poignee. Si `block` fait partie d'une plage
    /// MULTI-blocs deja selectionnee, TOUTE la plage se deplace solidairement (docs/10 :
    /// "deplacement multi-blocs") ; sinon seul `block` est concerne.
    public func beginBlockDrag(_ block: Block) {
        if let range = blockSelectionRange, !range.isSingleBlock {
            let ids = BlockSelectionOperations.orderedBlockIDs(of: range, in: note)
            if ids.contains(block.id) {
                draggedBlockIDs = Set(ids)
                return
            }
        }
        draggedBlockIDs = [block.id]
    }

    /// Variante de `beginBlockDrag(_:)` pour le point d'entree DropDelegate, qui ne
    /// recoit que l'UUID transporte par la session native (`String`, voir la
    /// documentation de tete de fichier), jamais un `Block` directement.
    public func beginBlockDrag(byID id: UUID) {
        guard let block = BlockOrdering.flattenedBlocks(of: note).first(where: { $0.id == id }) else { return }
        beginBlockDrag(block)
    }

    /// A appeler en continu pendant le survol (`DropDelegate.dropUpdated(info:)`),
    /// `pointerLocation` dans la MEME `coordinateSpace` que `blockFrames`.
    public func updateBlockDragTarget(pointerLocation: CGPoint) {
        dragTarget = BlockDropResolution.resolve(pointerLocation: pointerLocation, blockFrames: blockFrames)
    }

    /// Nombre de fichiers actuellement glisses au-dessus de l'editeur (`nil` si le
    /// glisser en cours ne transporte pas de fichiers) -- pilote le badge de comptage de
    /// `BlockDropIndicatorView` (artboard C de P2, "a partir de 2 fichiers").
    public func updateDragFileCount(_ count: Int?) {
        dragFileCount = count
    }

    /// Sortie de survol (`DropDelegate.dropExited(info:)`) : nettoie IMMEDIATEMENT tout
    /// l'etat visuel, sans animation (docs/10, tache 3 : "sortie de survol immediate
    /// sans animation") -- y compris `draggedBlockIDs`, plutot que le laisser
    /// indefiniment estompe si le glisser se termine hors de tout depot valide (aucun
    /// hook SwiftUI fiable pour "session de glisser annulee" au niveau de la SOURCE,
    /// voir le rapport de fin de tache).
    public func endBlockDrag() {
        draggedBlockIDs = []
        dragTarget = nil
        dragFileCount = nil
    }

    // MARK: - Depot d'un/plusieurs blocs (voir `BlockDropResolution`/`ColumnStructure`)

    /// Execute le depot au point courant : reordonnancement (frontiere haute/basse) ou
    /// creation/extension de colonne (tiers lateral). `false` sans effet si aucune
    /// cible valide n'est resolue, si `draggedBlockIDs` est vide, ou si la cible est
    /// elle-meme l'un des blocs deplaces (ou l'un de ses propres descendants -- deplacer
    /// un bloc DANS son propre sous-arbre creerait un cycle).
    @discardableResult
    public func performBlockDrop(pointerLocation: CGPoint) -> Bool {
        defer { endBlockDrag() }
        guard let target = BlockDropResolution.resolve(pointerLocation: pointerLocation, blockFrames: blockFrames),
              !draggedBlockIDs.isEmpty, !draggedBlockIDs.contains(target.blockID) else {
            return false
        }
        let flat = BlockOrdering.flattenedBlocks(of: note)
        guard let targetBlock = flat.first(where: { $0.id == target.blockID }) else { return false }
        // Ordre DFS aplati preserve l'ordre d'affichage des blocs deplaces, meme motif
        // que `BlockSelectionOperations.orderedBlocks(of:in:)`.
        let draggedBlocks = flat.filter { draggedBlockIDs.contains($0.id) }
        guard !draggedBlocks.contains(where: { isAncestor($0, of: targetBlock) }) else { return false }

        switch target.edge {
        case .leading, .trailing:
            return performLateralDrop(draggedBlocks: draggedBlocks, target: targetBlock, edge: target.edge)
        case .top, .bottom:
            return performVerticalDrop(draggedBlocks: draggedBlocks, target: targetBlock, edge: target.edge)
        }
    }

    /// Depot LATERAL (tiers gauche/droit d'un bloc) : cree une nouvelle mise en
    /// colonnes, ou ajoute une colonne a celle qui porte deja `target` s'il en fait deja
    /// partie. Restreint a UN SEUL bloc deplace (docs/10 ne definit pas de semantique
    /// pour "deposer une plage de blocs lateralement").
    private func performLateralDrop(draggedBlocks: [Block], target: Block, edge: Edge) -> Bool {
        guard draggedBlocks.count == 1, let moved = draggedBlocks.first else { return false }
        guard ColumnStructure.canEnterColumn(target), ColumnStructure.canEnterColumn(moved) else { return false }

        if let column = target.parent, column.type == .column,
           let columnList = column.parent, columnList.type == .columnList {
            let columns = BlockOrdering.children(of: columnList)
            guard let columnIndex = columns.firstIndex(where: { $0.id == column.id }) else { return false }
            let insertIndex = edge == .trailing ? columnIndex + 1 : columnIndex
            addColumn(moving: moved, to: columnList, at: insertIndex)
        } else {
            createColumns(moving: moved, onto: target, edge: edge)
        }
        return true
    }

    /// Depot HORIZONTAL (haut/bas d'un bloc) : reordonnancement pur et simple, y
    /// compris a travers un changement de `parent` (sortie/entree de colonne ou de
    /// liste). Chaque bloc deplace est detache PUIS reinsere via les primitives
    /// eprouvees de `BlockOrdering` (jamais de mutation directe de `order`) : `.top`
    /// insere chacun, DANS L'ORDRE, juste avant `target` (`insert(_:before:)` place
    /// toujours son argument immediatement adjacent a l'ancre, donc repeter cet appel
    /// dans l'ordre du groupe suffit) ; `.bottom` utilise une ANCRE ROULANTE (chaque
    /// bloc insere devient l'ancre du suivant) -- meme motif exact que
    /// `ColumnStructure.dissolve(_:remainingColumn:)`.
    private func performVerticalDrop(draggedBlocks: [Block], target: Block, edge: Edge) -> Bool {
        guard !draggedBlocks.isEmpty, edge == .top || edge == .bottom else { return false }
        if let parent = target.parent, parent.type == .column {
            guard draggedBlocks.allSatisfy(ColumnStructure.canEnterColumn) else { return false }
        }

        // Colonnes que ces blocs quittent potentiellement (capture AVANT toute
        // mutation) : dissoutes/nettoyees APRES le deplacement si elles se retrouvent
        // videes -- voir `dissolveIfEmptied(_:)`.
        let previousColumnLists = Self.columnListAncestors(of: draggedBlocks)

        if edge == .top {
            for block in draggedBlocks {
                BlockOrdering.detachPreservingChildren(block)
                BlockOrdering.invalidateCache(for: note)
                BlockOrdering.insert(block, before: target)
            }
        } else {
            var anchor = target
            for block in draggedBlocks {
                BlockOrdering.detachPreservingChildren(block)
                BlockOrdering.invalidateCache(for: note)
                BlockOrdering.insert(block, after: anchor)
                anchor = block
            }
        }

        for columnList in previousColumnLists {
            dissolveIfEmptied(columnList)
        }
        persistStructuralChange()
        return true
    }

    /// `columnList` ancetre DIRECT (via une `.column`) de chaque bloc de `blocks` qui en
    /// a un, sans doublon -- extrait de `performVerticalDrop(draggedBlocks:target:edge:)`
    /// pour rester sous la limite de complexite cyclomatique de SwiftLint.
    private static func columnListAncestors(of blocks: [Block]) -> [Block] {
        var result: [Block] = []
        var seenIDs = Set<UUID>()
        for block in blocks {
            guard let parent = block.parent, parent.type == .column,
                  let columnList = parent.parent, columnList.type == .columnList,
                  seenIDs.insert(columnList.id).inserted else { continue }
            result.append(columnList)
        }
        return result
    }

    /// `true` si `ancestor` est un ANCETRE de `block` (ou `block` lui-meme) -- deplacer
    /// un bloc a l'interieur de son propre sous-arbre creerait un cycle `parent`, jamais
    /// tente ici.
    private func isAncestor(_ ancestor: Block, of block: Block) -> Bool {
        var current: Block? = block
        while let candidate = current {
            if candidate.id == ancestor.id { return true }
            current = candidate.parent
        }
        return false
    }

    // MARK: - Depot de fichiers n'importe ou dans l'editeur (report Phase 9, artboard C
    // de P2)

    /// Depot d'un ou plusieurs fichiers (glisses depuis le Finder) : cree un bloc par
    /// fichier a la position resolue (meme frontiere que `performBlockDrop(pointerLocation:)`),
    /// dans l'ORDRE des `providers`. Sans cible resolue (note sans aucun bloc), les
    /// fichiers sont ajoutes en fin de note. Reutilise EXCLUSIVEMENT le pipeline DEJA
    /// EPROUVE d'`EditorController+Attachments.swift` (`importImageFile(at:into:)`/
    /// `importAttachedFile(at:into:)`) -- y compris son garde `block.modelContext ==
    /// nil` post-`await`, jamais reimplemente ici.
    @discardableResult
    public func performFileDrop(providers: [NSItemProvider], pointerLocation: CGPoint) -> Bool {
        defer { endBlockDrag() }
        guard !providers.isEmpty else { return false }

        let target = BlockDropResolution.resolve(pointerLocation: pointerLocation, blockFrames: blockFrames)
        var anchor = target.flatMap(resolveTargetBlock)
        // `.leading`/`.top` => les fichiers prennent la place AVANT la cible ; `.trailing`/
        // `.bottom` => APRES. Les fichiers n'ont pas de semantique de colonne (jamais
        // `.leading`/`.trailing` a proprement parler), seule la MOITIE survolee compte.
        var insertBefore = target?.edge == .leading || target?.edge == .top

        for provider in providers {
            let type = Self.guessedFileBlockType(for: provider)
            let newBlock = Block(type: type)
            if let anchorBlock = anchor {
                if insertBefore {
                    BlockOrdering.insert(newBlock, before: anchorBlock)
                } else {
                    BlockOrdering.insert(newBlock, after: anchorBlock)
                }
            } else {
                appendAtEndOfDocument(newBlock)
            }
            persistStructuralChange()
            anchor = newBlock
            insertBefore = false // Les fichiers suivants s'enchainent APRES celui-ci, dans l'ordre du depot.
            loadDroppedFile(from: provider, into: newBlock, expectedType: type)
        }
        return true
    }

    private func resolveTargetBlock(_ target: BlockDropTarget) -> Block? {
        BlockOrdering.flattenedBlocks(of: note).first { $0.id == target.blockID }
    }

    /// Meme idiome que `appendTrailingParagraph()` : ajoute `newBlock` en toute fin de
    /// note, y compris sur une note totalement vide.
    private func appendAtEndOfDocument(_ newBlock: Block) {
        if let last = BlockOrdering.flattenedBlocks(of: note).last {
            BlockOrdering.insert(newBlock, after: last)
        } else {
            newBlock.note = note
            note.blocks = [newBlock]
            BlockOrdering.invalidateCache(for: note)
        }
    }

    /// Type de bloc a creer pour un `NSItemProvider` donne, avant meme d'avoir charge
    /// son contenu (synchronement -- `hasItemConformingToTypeIdentifier` n'exige aucun
    /// chargement) : `.image` s'il declare conformer a `public.image`, `.file` sinon.
    /// Le CHARGEMENT reel (et le refus d'un dossier, `AttachmentImportError.
    /// isDirectory`) reste entierement a la charge du pipeline existant, voir
    /// `loadDroppedFile(from:into:expectedType:)`.
    private static func guessedFileBlockType(for provider: NSItemProvider) -> BlockType {
        provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) ? .image : .file
    }

    /// Charge l'URL portee par `provider` puis la fait transiter par le pipeline
    /// EXISTANT (`importImageFile(at:into:)`/`importAttachedFile(at:into:)`), qui gere
    /// deja seul le refus d'un dossier et l'enregistrement de la cause d'echec (voir la
    /// documentation de tete de fichier). Ne capture QUE `block.id` (`UUID`, `Sendable`)
    /// dans le gestionnaire `@Sendable` de `loadObject(ofClass:completionHandler:)` --
    /// jamais `block` lui-meme (`Block` n'est pas `Sendable`, Swift 6 mode strict) -- et
    /// re-resout le `Block` correspondant apres le saut sur l'acteur principal, avec la
    /// meme garde "peut avoir ete supprime entre-temps" que le reste de ce module.
    private func loadDroppedFile(from provider: NSItemProvider, into block: Block, expectedType: BlockType) {
        let blockID = block.id
        _ = provider.loadObject(ofClass: URL.self) { [weak self] url, _ in
            guard let url else { return }
            Task { @MainActor in
                guard let self else { return }
                let flattened = BlockOrdering.flattenedBlocks(of: self.note)
                guard let resolvedBlock = flattened.first(where: { $0.id == blockID }) else { return }
                if expectedType == .image {
                    self.importImageFile(at: url, into: resolvedBlock)
                } else {
                    self.importAttachedFile(at: url, into: resolvedBlock)
                }
            }
        }
    }
}
