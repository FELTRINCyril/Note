import Foundation
import SlateModel

/// Fonctions pures de tri et de navigation dans l'arbre de blocs d'une `Note`.
///
/// SwiftData n'a pas de relation ordonnee (voir `Block.order` dans `SlateModel`) :
/// aucune lecture ne doit se fier a l'ordre d'insertion de `note.blocks` ou de
/// `block.children`, toujours trier explicitement par `order`. Ce type centralise ce
/// tri pour que le routeur de bloc (`NoteDocumentView`/`BlockTreeView`) n'ait jamais a
/// le refaire lui-meme, et pour que la regle reste testable independamment de SwiftUI.
///
/// ## Cache de l'ordre aplati
/// `flattenedBlocks(of:)`/`topLevelBlocks(of:)`/`block(before:)`/`block(after:)` lisent
/// un cache PAR `Note`, invalide a chaque mutation structurelle -- voir
/// `BlockOrderingCache.swift` (dans le meme type, extrait dans un fichier separe
/// uniquement pour la limite de longueur de `CLAUDE.md` §5) pour la justification
/// complete et la regle d'invalidation, la SEULE qui compte pour la surete de ce cache.
/// `@MainActor` -- ce cache n'est jamais accede depuis un autre contexte d'execution,
/// donc jamais besoin d'etre `Sendable`.
@MainActor
public enum BlockOrdering {
    /// Trie une liste de blocs freres par `order` croissant.
    public static func sortedByOrder(_ blocks: [Block]) -> [Block] {
        blocks.sorted { $0.order < $1.order }
    }

    /// Blocs racine d'une note (sans parent), tries par `order`. Derive du cache aplati
    /// (`cachedOrder(for:)`, DFS qui visite les racines dans leur ordre trie avant de
    /// descendre dans chaque sous-arbre) : un simple filtre `parent == nil` sur
    /// `flattened` prevserve exactement cet ordre relatif, sans retrier.
    public static func topLevelBlocks(of note: Note) -> [Block] {
        cachedOrder(for: note).flattened.filter { $0.parent == nil }
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

    // MARK: - Ordre visuel complet du document (docs/05_editeur_blocs.md, sous-etape 5.3)

    /// Tous les blocs d'une note, en ordre de lecture EXACT (parcours en profondeur,
    /// prefixe) : un bloc racine, puis recursivement tous ses enfants avant son frere
    /// suivant. C'est EXACTEMENT l'ordre dans lequel `BlockTreeView` les rend a l'ecran
    /// (bloc, puis `ForEach` de ses enfants) -- indispensable pour que la navigation au
    /// clavier (fleches haut/bas, fusion au retour arriere) suive le meme ordre que ce
    /// que l'utilisateur voit, y compris a travers l'imbrication d'une liste. Renvoie
    /// directement le tableau du cache (voir la documentation de tete de fichier) :
    /// O(1) tant qu'aucune mutation structurelle n'a eu lieu depuis la derniere lecture.
    public static func flattenedBlocks(of note: Note) -> [Block] {
        cachedOrder(for: note).flattened
    }

    /// Bloc precedent de `block` dans l'ordre visuel complet du document (voir
    /// `flattenedBlocks(of:)`), ou `nil` si `block` est le tout premier bloc de sa note
    /// (aucun bloc au-dessus dans l'ordre de lecture) ou n'appartient a aucune note.
    public static func block(before block: Block) -> Block? {
        guard let note = block.note else { return nil }
        let cache = cachedOrder(for: note)
        guard let index = cache.flattenedIndexByID[block.id], index > 0 else { return nil }
        return cache.flattened[index - 1]
    }

    /// Symmetrique de `block(before:)` : bloc suivant dans l'ordre visuel complet.
    public static func block(after block: Block) -> Block? {
        guard let note = block.note else { return nil }
        let cache = cachedOrder(for: note)
        guard let index = cache.flattenedIndexByID[block.id], index < cache.flattened.count - 1 else { return nil }
        return cache.flattened[index + 1]
    }

    /// Pas `private` : `BlockOrderingCache.swift` (extension separee de ce meme type,
    /// voir sa documentation) l'appelle pour construire `DocumentOrderCache.flattened`.
    static func appendSubtree(of block: Block, into result: inout [Block]) {
        result.append(block)
        for child in children(of: block) {
            appendSubtree(of: child, into: &result)
        }
    }

    // MARK: - Mutations (insertion / suppression avec renumerotation de `order`)
    //
    // SwiftData n'a pas de relation ordonnee (voir la documentation de tete de fichier) :
    // toute insertion/suppression parmi des blocs freres doit a la fois (1) placer le
    // bloc au bon endroit dans le tableau relationnel (`note.blocks`/`parent.children`)
    // ET (2) renumeroter `order` de TOUS les freres pour qu'il reste une suite compacte
    // 0..n-1 reflette exactement leur position -- sinon deux blocs pourraient se
    // retrouver avec le meme `order`, ou un trou, et l'ordre de lecture se desynchronise
    // silencieusement du tableau. Renumeroter systematiquement l'ensemble des freres a
    // chaque mutation (plutot qu'un schema d'ordres fractionnaires) reste simple a
    // auditer et bon marche : un bloc n'a jamais plus de quelques centaines de freres.
    //
    // Comme les tests de ce module (`note.blocks = [...]` sans `ModelContext`, voir
    // `BlockOrderingTests`), ces fonctions manipulent DIRECTEMENT les deux cotes de la
    // relation (`Block.note`/`parent` ET `Note.blocks`/`Block.children`) : en l'absence
    // d'un contexte SwiftData vivant, l'inverse d'une relation ne se synchronise pas
    // seul.

    /// Insere `newBlock` juste APRES `anchor` parmi ses freres (meme `note`/`parent` que
    /// `anchor`), puis renumerote toute la fratrie -- sauf raccourci O(1)
    /// (`appendAsCompactLastSibling(_:after:)`) quand `anchor` est demontre etre le
    /// DERNIER bloc de la note (voir sa documentation).
    public static func insert(_ newBlock: Block, after anchor: Block) {
        if appendAsCompactLastSibling(newBlock, after: anchor) {
            return
        }
        insert(newBlock, relativeTo: anchor, offset: 1)
    }

    /// Insere `newBlock` juste AVANT `anchor` parmi ses freres, puis renumerote toute la
    /// fratrie.
    public static func insert(_ newBlock: Block, before anchor: Block) {
        insert(newBlock, relativeTo: anchor, offset: 0)
    }

    /// Retire `block` de la fratrie qui le porte (`note.blocks` ou `parent.children`) et
    /// renumerote les blocs restants pour combler le trou. Les enfants directs de
    /// `block`, s'il en a, sont PROMUS a sa place exacte (memes `note`/`parent` que
    /// `block` avant sa suppression) plutot que supprimes en cascade : retirer un bloc
    /// ne doit jamais faire disparaitre silencieusement du contenu (docs/05_editeur_blocs.md,
    /// sous-etape 5.3 : "ne pas supprimer le dernier bloc restant de la note", generalise
    /// ici a "ne jamais perdre de bloc" pour toute suppression structurelle).
    public static func remove(_ block: Block) {
        let parent = block.parent
        let note = block.note
        let promotedChildren = sortedByOrder(block.children ?? [])

        var siblings = siblingsCollection(of: block)
        guard let index = siblings.firstIndex(where: { $0.id == block.id }) else {
            detach(block)
            invalidateCache(for: note)
            return
        }
        siblings.remove(at: index)

        for child in promotedChildren {
            child.parent = parent
            child.note = note
        }
        siblings.insert(contentsOf: promotedChildren, at: index)

        renumber(siblings)
        writeBack(siblings, parent: parent, note: note)
        detach(block)
        invalidateCache(for: note)
    }

    /// Retire TOUS les blocs de `blocks` en une seule passe -- SEULEMENT s'ils sont tous
    /// freres DIRECTS les uns des autres (meme `parent`, meme `note`). Reutilise par
    /// `BlockSelectionOperations.deleteRange(_:in:)` : sans elle, supprimer m blocs d'une
    /// selection en lot appelait `remove(_:)` m fois, chacune recalculant la fratrie
    /// ENTIERE (O(n)) -- suppression de m blocs sur n = O(m*n), mesure et documente par
    /// `BlockPerformanceTests.deleteSelectionRangeScaling` (revue finale de Phase 5).
    ///
    /// La condition "meme parent direct" garantit qu'AUCUN bloc de `blocks` n'est
    /// l'ancetre d'un autre bloc de `blocks` : un descendant a necessairement un
    /// `parent` different de celui de ses freres, donc different de celui du groupe --
    /// s'il figurait dans `blocks`, la condition serait fausse et cette fonction
    /// retomberait sur le chemin general (`remove(_:)` bloc par bloc, TOUJOURS correct,
    /// juste pas optimise pour ce cas). C'est cette garantie qui rend une seule passe
    /// (la fratrie calculee UNE fois, chaque bloc a retirer remplace par ses propres
    /// enfants promus au meme endroit) rigoureusement equivalente au retrait bloc par
    /// bloc.
    public static func removeAll(_ blocks: [Block]) {
        guard let first = blocks.first else { return }
        let sameFratrie = blocks.allSatisfy { $0.parent?.id == first.parent?.id && $0.note?.id == first.note?.id }
        guard sameFratrie else {
            for block in blocks { remove(block) }
            return
        }
        removeBatchWithinSameFratrie(blocks, parent: first.parent, note: first.note)
    }

    private static func removeBatchWithinSameFratrie(_ blocksToRemove: [Block], parent: Block?, note: Note?) {
        let removeIDs = Set(blocksToRemove.map(\.id))
        let siblings = siblingsCollection(of: blocksToRemove[0])

        var result: [Block] = []
        result.reserveCapacity(siblings.count)
        for sibling in siblings {
            guard removeIDs.contains(sibling.id) else {
                result.append(sibling)
                continue
            }
            let promoted = sortedByOrder(sibling.children ?? [])
            for child in promoted {
                child.parent = parent
                child.note = note
            }
            result.append(contentsOf: promoted)
        }

        renumber(result)
        writeBack(result, parent: parent, note: note)
        for block in blocksToRemove {
            detach(block)
        }
        invalidateCache(for: note)
    }

    private static func insert(_ newBlock: Block, relativeTo anchor: Block, offset: Int) {
        newBlock.note = anchor.note
        newBlock.parent = anchor.parent

        var siblings = siblingsCollection(of: anchor)
        siblings.removeAll { $0.id == newBlock.id }
        let anchorIndex = siblings.firstIndex(where: { $0.id == anchor.id }) ?? siblings.count
        siblings.insert(newBlock, at: min(anchorIndex + offset, siblings.count))

        renumber(siblings)
        writeBack(siblings, parent: anchor.parent, note: anchor.note)
        invalidateCache(for: anchor.note)
    }

    /// Freres directs de `block` (memes `note`/`parent`), tries par `order`. Version
    /// PUBLIQUE, en LECTURE, de `siblingsCollection(of:)` ci-dessous -- pour les
    /// operations de menu (`BlockOperations`, sous-etape 5.4) qui doivent lire une
    /// fratrie sans la muter (`insert`/`remove` restent le seul chemin de mutation
    /// structurelle passant par cette fratrie).
    public static func siblings(of block: Block) -> [Block] {
        siblingsCollection(of: block)
    }

    /// Freres directs de `block` (memes `note`/`parent`), tries par `order` -- lit
    /// indifferemment `parent.children` (bloc imbrique) ou les blocs RACINE de `note`
    /// (bloc racine). Pour un bloc racine, reutilise `topLevelBlocks(of:)` -- PAS
    /// `note.blocks` brut : `note.blocks` porte TOUS les blocs de la note (racine ET
    /// imbriques, c'est l'inverse de `Block.note`, distinct de l'arborescence
    /// `parent`/`children`), l'oublier ici renumeroterait `order` en melangeant des
    /// blocs de niveaux differents (bug reproduit par `BlockOrderingTests`).
    private static func siblingsCollection(of block: Block) -> [Block] {
        if let parent = block.parent {
            return sortedByOrder(parent.children ?? [])
        }
        if let note = block.note {
            return topLevelBlocks(of: note)
        }
        return []
    }

    private static func renumber(_ siblings: [Block]) {
        for (index, sibling) in siblings.enumerated() {
            sibling.order = index
        }
    }

    /// Ecrit `siblings` (la fratrie mise a jour, racine ou imbriquee) dans la relation
    /// qui la porte. Pour une fratrie RACINE, `siblings` ne contient QUE des blocs
    /// racine (voir `siblingsCollection(of:)`) : les blocs imbriques deja presents dans
    /// `note.blocks` sont PRESERVES explicitement (concatenes) plutot qu'ecrases -- une
    /// affectation de `note.blocks` qui les omettrait romprait leur relation inverse
    /// (`Block.note`), meme sans `ModelContext` vivant.
    private static func writeBack(_ siblings: [Block], parent: Block?, note: Note?) {
        if let parent {
            parent.children = siblings
            return
        }
        guard let note else { return }
        let nested = (note.blocks ?? []).filter { $0.parent != nil }
        note.blocks = siblings + nested
    }

    private static func detach(_ block: Block) {
        block.note = nil
        block.parent = nil
        block.children = []
    }
}
