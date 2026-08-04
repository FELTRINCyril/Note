import Foundation
import SlateModel

/// Cache de l'ordre aplati d'une note -- extrait de `BlockOrdering.swift` (revue finale
/// de Phase 5, cout quadratique mesure) uniquement pour rester sous la limite de
/// longueur de fichier de `CLAUDE.md` §5 : ce fichier n'ajoute AUCUNE nouvelle surface
/// publique qui lui serait propre, `BlockOrdering` reste un SEUL type.
///
/// ## Le probleme (voir `BlockPerformanceTests`)
/// `flattenedBlocks(of:)`/`topLevelBlocks(of:)`/`block(before:)`/`block(after:)` etaient
/// TOUS recalcules par un parcours complet (DFS, avec un tri a chaque niveau) A CHAQUE
/// APPEL. Sans cache, une frappe d'Entree repetee ou une traversee clavier complete
/// d'une note de 500+ blocs est QUADRATIQUE PAR CONSTRUCTION : n appels consecutifs
/// (n insertions en fin de note, n pressions de fleche...) coutent chacun O(n), soit
/// O(n^2) au total -- mesure et documente par `BlockPerformanceTests` (revue finale de
/// Phase 5, ratios 14 a 16 pour un facteur d'echelle de 4).
///
/// Toute lecture de l'ordre passe desormais par un cache PAR `Note`
/// (`cachedOrder(for:)`), construit au besoin (`DocumentOrderCache`, un simple DFS deja
/// calcule + son index inverse `UUID -> position` pour une navigation O(1)).
///
/// **Invalidation -- la seule regle qui compte pour la SURETE de ce cache.** Le cache
/// d'une note est INVALIDE (retire du `NSMapTable`) a la fin de TOUTE fonction qui
/// modifie la structure de l'arbre : `insert`, `remove`, `removeAll`, et le
/// reordonnancement de `BlockOperations.move`/`BlockSelectionOperations.moveRange`
/// (qui mutent `order` sans passer par `insert`/`remove` -- portee volontairement
/// restreinte aux freres de meme niveau, voir leur documentation -- et appellent donc
/// `invalidateCache(for:)` EXPLICITEMENT). Toute prochaine lecture apres une
/// invalidation reconstruit le cache ENTIEREMENT depuis `note.blocks`/`block.children`
/// (jamais depuis une trace partielle) : TOUJOURS correct, jamais de bloc fantome, au
/// prix d'un seul O(n).
///
/// La SEULE exception est le raccourci incremental de `appendAsCompactLastSibling(_:after:)` :
/// il met a jour le cache EN PLACE plutot que de l'invalider, mais UNIQUEMENT dans des
/// conditions etroites ou la nouvelle position est demontree correcte sans reparcourir
/// le document (voir sa documentation en detail). Toute condition non remplie retombe
/// sur le chemin general, qui invalide sans jamais deviner -- c'est ce raccourci,
/// et lui seul, qui rend une construction par insertions successives en fin de note
/// lineaire plutot que quadratique.
///
/// **Portee du cache.** Un cache par `Note`, cle FAIBLE
/// (`NSMapTable(.weakToStrongObjects)`) : pas de fuite si une note est desallouee, et
/// surtout pas de risque de collision d'identite avec un `ObjectIdentifier` recycle
/// apres liberation memoire (un dictionnaire keye par une valeur brute n'aurait aucune
/// garantie a ce sujet). `@MainActor` -- comme `BlockOrdering` lui-meme : jamais accede
/// depuis un autre contexte d'execution, donc jamais besoin d'etre `Sendable`.
extension BlockOrdering {
    /// Photo de l'ordre complet d'une note : l'aplati DFS (`flattened`) avec son index
    /// inverse pour une navigation O(1) (`flattenedIndexByID`). Un `final class` (pas
    /// une `struct`) : necessaire pour vivre dans un `NSMapTable`, et pour que
    /// `appendAsCompactLastSibling(_:after:)` puisse l'etendre EN PLACE (meme reference
    /// que celle deja stockee dans le cache) sans reconstruire tout son index.
    final class DocumentOrderCache {
        private(set) var flattened: [Block]
        private(set) var flattenedIndexByID: [UUID: Int]

        init(flattened: [Block]) {
            self.flattened = flattened
            var index: [UUID: Int] = [:]
            index.reserveCapacity(flattened.count)
            for (position, block) in flattened.enumerated() {
                index[block.id] = position
            }
            self.flattenedIndexByID = index
        }

        /// Etend le cache d'UN bloc en position finale, en O(1) amorti -- voir
        /// `appendAsCompactLastSibling(_:after:)`, le SEUL appelant. Jamais utilise pour
        /// une insertion a une position quelconque (qui invaliderait plutot ce cache).
        func appendAtEnd(_ block: Block) {
            flattenedIndexByID[block.id] = flattened.count
            flattened.append(block)
        }
    }

    /// Le cache, un par `Note` -- voir la documentation de tete de fichier. `internal`
    /// (pas `private`) : ce fichier est une extension separee de la declaration
    /// principale de `BlockOrdering`, qui doit pouvoir le lire (`topLevelBlocks(of:)`,
    /// `flattenedBlocks(of:)`, `block(before:)`/`block(after:)`).
    static let orderCache = NSMapTable<Note, DocumentOrderCache>.weakToStrongObjects()

    /// Cache VALIDE pour `note`, en le (re)construisant au besoin depuis
    /// `note.blocks`/`block.children` -- SEUL point d'entree vers `orderCache` en
    /// LECTURE, pour que "construire" et "lire" restent un seul chemin, jamais deux
    /// implementations paralleles qui pourraient diverger.
    static func cachedOrder(for note: Note) -> DocumentOrderCache {
        if let existing = orderCache.object(forKey: note) {
            return existing
        }
        var flat: [Block] = []
        for root in sortedByOrder((note.blocks ?? []).filter { $0.parent == nil }) {
            appendSubtree(of: root, into: &flat)
        }
        let fresh = DocumentOrderCache(flattened: flat)
        orderCache.setObject(fresh, forKey: note)
        return fresh
    }

    /// Invalide le cache de `note` : a appeler a la fin de TOUTE mutation structurelle
    /// (voir la documentation de tete de fichier). Pas `private` : `BlockOperations.move`
    /// et `BlockSelectionOperations.moveRange` mutent `order` SANS passer par
    /// `insert`/`remove` et doivent donc invalider explicitement depuis leur module.
    static func invalidateCache(for note: Note?) {
        guard let note else { return }
        orderCache.removeObject(forKey: note)
    }

    /// Raccourci O(1) amorti pour ajouter un bloc juste apres le bloc GLOBALEMENT
    /// DERNIER de la note -- le seul motif exerce par la frappe repetee d'Entree en fin
    /// de note (`EditorController.appendTrailingParagraph`/`insertBlockBelow` sur le
    /// dernier bloc, voir `BlockPerformanceTests.appendTrailingParagraphScaling`, revue
    /// finale de Phase 5). Sans lui, CHAQUE insertion recalcule la fratrie racine
    /// ENTIERE (`siblingsCollection`, qui filtre `note.blocks` -- lui-meme melange
    /// racine et imbrique, voir sa documentation) : n insertions successives en fin de
    /// note coutent alors O(n^2).
    ///
    /// Retourne `false` (aucun effet) -- laissant `insert(_:relativeTo:offset:)` s'en
    /// charger de la maniere generale, toujours correcte -- des que l'une de ces
    /// conditions n'est PAS remplie :
    /// - `anchor` est un bloc RACINE (`parent == nil`) : seul niveau ou `note.blocks`
    ///   melange racine et imbrique rend `siblingsCollection` couteux ;
    /// - `anchor` N'A AUCUN ENFANT : sinon le dernier bloc de la fratrie racine ne
    ///   serait pas non plus le dernier bloc au sens de l'ordre DFS complet
    ///   (`flattenedBlocks(of:)`), et ce raccourci ne pretend pas reconstruire ce cas ;
    /// - le cache aplati de la note est DEJA construit et se termine PRECISEMENT par
    ///   `anchor` (`cache.flattened.last?.id == anchor.id`) -- si le cache n'existe pas
    ///   encore ou est perime, ce raccourci NE DEVINE RIEN.
    ///
    /// `newBlock.order = anchor.order + 1` (jamais un `renumber` complet de la fratrie) :
    /// valide UNIQUEMENT parce qu'`anchor` est demontre etre le DERNIER de sa fratrie
    /// racine, compacte 0..m-1 par invariant (voir la documentation de tete de fichier
    /// de `BlockOrdering.swift`, section "Mutations") -- `anchor.order` vaut donc
    /// exactement `m - 1`, et `m` est l'`order` correct pour `newBlock`.
    @discardableResult
    static func appendAsCompactLastSibling(_ newBlock: Block, after anchor: Block) -> Bool {
        guard anchor.parent == nil, (anchor.children ?? []).isEmpty,
              let note = anchor.note,
              let cache = orderCache.object(forKey: note),
              cache.flattened.last?.id == anchor.id else {
            return false
        }

        newBlock.note = note
        newBlock.parent = nil
        newBlock.order = anchor.order + 1
        if note.blocks == nil {
            note.blocks = [newBlock]
        } else {
            note.blocks?.append(newBlock)
        }

        cache.appendAtEnd(newBlock)
        return true
    }
}
