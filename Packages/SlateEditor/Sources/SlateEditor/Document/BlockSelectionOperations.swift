import Foundation
import SlateModel
import SlateUI

/// Logique PURE (aucune dependance AppKit, aucun `ModelContext`) de la selection
/// multi-blocs (docs/05_editeur_blocs.md, sous-etape 5.6). Memes principes que
/// `BlockOperations`/`BlockConversion` : opere directement sur le graphe `Block`/`Note`
/// deja en memoire, entierement testable sans `NSTextView` ni fenetre.
/// `EditorController` reste la SEULE facade appelee par la couche SwiftUI.
///
/// ## Ordre de reference : le DFS aplati, jamais un tableau brut
/// Toute resolution d'une `BlockSelectionRange` en une plage de blocs REELLE passe par
/// `BlockOrdering.flattenedBlocks(of:)` -- l'ordre d'affichage EXACT (parcours en
/// profondeur prefixe), le meme que celui rendu par `BlockTreeView`. Une plage entre
/// deux blocs racine qui encadre une liste imbriquee DOIT inclure les items de cette
/// liste (c'est ce que l'utilisateur voit a l'ecran entre les deux clics) : indexer sur
/// `note.blocks` brut (ordre non specifie, melange racine/imbrique) produirait une
/// plage fausse a la premiere note qui contient de l'imbrication.
///
/// ## Suppression en lot et enfants NON selectionnes (le point delicat de la tache)
/// `deleteRange(_:in:)` supprime chaque bloc de la plage un par un via
/// `BlockOrdering.remove(_:)` -- EXACTEMENT le meme point d'entree que la suppression
/// d'un bloc unique (sous-etapes 5.3/5.4), reutilise sans dupliquer sa logique. Cela
/// signifie que le sort d'un enfant NON selectionne d'un bloc supprime de la plage est
/// IDENTIQUE a celui deja documente pour un unique bloc supprime : il est PROMU a la
/// place de son parent (jamais supprime en cascade), quel que soit l'ordre dans lequel
/// les blocs de la plage sont retires (l'identite objet `Block` reste stable a travers
/// une promotion, seuls ses pointeurs `parent`/`note` sont reecrits). Le filet de
/// securite "la note ne reste jamais sans aucun bloc" (sous-etape 5.3/5.4) n'est
/// applique QU'UNE FOIS, apres la boucle complete -- jamais a chaque bloc retire, pour
/// ne jamais inserer un paragraphe de secours superflu au milieu d'une suppression en
/// lot qui laisserait par ailleurs d'autres blocs promus derriere elle.
///
/// ## Deplacement en lot : restreint aux freres CONTIGUS de meme niveau
/// Meme restriction que `BlockOperations.moveUp(_:)`/`moveDown(_:)` (sous-etape 5.4),
/// generalisee : la plage entiere doit etre composee de freres directs du MEME parent
/// (`allSatisfy` sur `Block.parent?.id`) ET former un segment CONTIGU au sein de cette
/// fratrie (aucun frere non selectionne intercale) -- une plage qui traverse des
/// niveaux d'imbrication differents (ex: un bloc racine et un item de liste imbriquee)
/// est refusee, pour la meme raison que documentee sur `BlockOperations` : la
/// reindentation/renumerotation resultante souleverait des questions de conversion non
/// traitees avant la Phase 10 (drag & drop visuel). Le deplacement effectif ECHANGE le
/// groupe ENTIER avec le SEUL frere adjacent immediat (pas tout un autre groupe) : le
/// groupe se deplace comme un bloc solidaire, d'un cran, jamais plus.
///
/// ## Conversion en lot : les blocs non convertibles sont IGNORES, pas bloquants
/// `convertRange(_:to:in:)` convertit chaque bloc de la plage qui accepte `newType`
/// parmi `BlockConversion.availableTargets(for:)`, et laisse les autres INCHANGES --
/// plutot que de refuser l'operation entiere. Choix documente : selectionner cinq
/// lignes de texte et un separateur puis "Convertir en liste" doit convertir les cinq
/// lignes et laisser le separateur tel quel, pas echouer silencieusement sur les cinq
/// parce que le separateur ne peut pas suivre -- c'est l'usage le plus attendu
/// ("selectionner cinq lignes et les passer en liste a puces", docs/05_editeur_blocs.md)
/// et le plus tolerant a une selection heterogene faite a la souris/au clavier, ou
/// l'utilisateur n'a aucune raison de trier ses blocs par convertibilite avant d'agir.
@MainActor
public enum BlockSelectionOperations {
    // MARK: - Resolution de la plage contre le document (ordre DFS aplati)

    /// Tous les blocs de `range`, dans l'ORDRE D'AFFICHAGE REEL (voir la documentation
    /// de tete de fichier), bornes INCLUS. Vide si l'un des deux identifiants ne
    /// correspond plus a un bloc de `note` (bloc deja supprime entre-temps).
    public static func orderedBlocks(of range: BlockSelectionRange, in note: Note) -> [Block] {
        let flat = BlockOrdering.flattenedBlocks(of: note)
        guard let anchorIndex = flat.firstIndex(where: { $0.id == range.anchorBlockID }),
              let focusIndex = flat.firstIndex(where: { $0.id == range.focusBlockID }) else {
            return []
        }
        let lower = min(anchorIndex, focusIndex)
        let upper = max(anchorIndex, focusIndex)
        return Array(flat[lower...upper])
    }

    /// Identifiants de `orderedBlocks(of:in:)`, pour les appelants qui n'ont besoin que
    /// de l'identite des blocs (ex: verifier l'appartenance d'un `blockID` a la plage).
    public static func orderedBlockIDs(of range: BlockSelectionRange, in note: Note) -> [UUID] {
        orderedBlocks(of: range, in: note).map(\.id)
    }

    /// Association `blockID -> SlateBlockRangePosition` pour CHAQUE bloc de la plage
    /// (spec E4 : "coins arrondis seulement aux extremites de la plage"). Un seul bloc
    /// recoit `.single`, sinon le premier `.first`, le dernier `.last`, tout le reste
    /// `.middle` -- voir la documentation de `SlateBlockRangePosition` (`SlateUI`) pour
    /// la geometrie exacte que chaque cas produit (aplat continu, sans trou de 4 pt).
    public static func rangePositions(forOrderedIDs ids: [UUID]) -> [UUID: SlateBlockRangePosition] {
        guard ids.count > 1 else {
            return ids.reduce(into: [:]) { result, id in result[id] = .single }
        }
        var result: [UUID: SlateBlockRangePosition] = [:]
        let lastIndex = ids.count - 1
        for (index, id) in ids.enumerated() {
            switch index {
            case 0: result[id] = .first
            case lastIndex: result[id] = .last
            default: result[id] = .middle
            }
        }
        return result
    }

    // MARK: - Extension pas a pas (Maj+fleche haut/bas, spec E4 "Accessibilite")

    /// Deplace la tete (`focusBlockID`) de `range` d'UN pas dans l'ordre DFS aplati,
    /// en conservant l'ancre. Si `range` est `nil` (aucune selection en cours), l'ancre
    /// ET le point de depart de l'extension sont `fallbackBlockID` (le bloc ou le
    /// caret/la selection precedente se trouvait) -- premier Maj+fleche depuis
    /// l'edition d'un bloc selectionne, ce pas cree une plage de 2 blocs. `nil` si
    /// aucun bloc n'existe dans cette direction (bord du document) : l'appelant doit
    /// alors laisser le comportement natif (selection de texte intra-bloc) s'executer.
    public static func extendingByStep(
        from range: BlockSelectionRange?,
        fallbackBlockID: UUID,
        direction: BlockSelectionDirection,
        in note: Note
    ) -> BlockSelectionRange? {
        let base = range ?? BlockSelectionRange(single: fallbackBlockID)
        let flat = BlockOrdering.flattenedBlocks(of: note)
        guard let focusIndex = flat.firstIndex(where: { $0.id == base.focusBlockID }) else { return nil }
        let targetIndex = direction == .up ? focusIndex - 1 : focusIndex + 1
        guard flat.indices.contains(targetIndex) else { return nil }
        return BlockSelectionRange(anchorBlockID: base.anchorBlockID, focusBlockID: flat[targetIndex].id)
    }

    // MARK: - Suppression en lot (voir la documentation de tete de fichier)

    /// Supprime tous les blocs de `range`. Si la note se retrouve entierement vide a
    /// l'issue de la boucle, un paragraphe vide de secours est insere -- meme garde-fou
    /// que `BlockOperations.remove(_:from:)`, applique ICI UNE SEULE FOIS pour tout le
    /// lot (voir la documentation de tete de fichier).
    public static func deleteRange(_ range: BlockSelectionRange, in note: Note) {
        let blocksToDelete = orderedBlocks(of: range, in: note)
        for block in blocksToDelete {
            BlockOrdering.remove(block)
        }
        guard (note.blocks ?? []).isEmpty else { return }
        let fallback = Block(type: .paragraph, text: RichText())
        fallback.note = note
        note.blocks = [fallback]
    }

    // MARK: - Deplacement en lot (voir la documentation de tete de fichier)

    /// La plage peut-elle se deplacer d'un cran dans la direction donnee (`offset` :
    /// `-1` haut, `+1` bas) ? Verification SANS mutation, reutilisee a la fois par
    /// `moveRangeUp(_:in:)`/`moveRangeDown(_:in:)` et par l'appelant SwiftUI (etat
    /// desactive des entrees "Deplacer..." du menu de bloc en mode plage).
    public static func canMoveRange(_ range: BlockSelectionRange, in note: Note, by offset: Int) -> Bool {
        guard let bounds = contiguousSiblingBounds(of: range, in: note) else { return false }
        return offset < 0 ? bounds.firstIndex > 0 : bounds.siblings.indices.contains(bounds.lastIndex + 1)
    }

    /// Deplace la plage entiere d'UN cran vers le HAUT parmi ses freres CONTIGUS de
    /// meme niveau. `false` (aucun effet) si la plage traverse des niveaux differents,
    /// n'est pas contigue au sein de sa fratrie, ou est deja en tete.
    @discardableResult
    public static func moveRangeUp(_ range: BlockSelectionRange, in note: Note) -> Bool {
        moveRange(range, in: note, by: -1)
    }

    /// Symmetrique de `moveRangeUp(_:in:)` : un cran vers le BAS.
    @discardableResult
    public static func moveRangeDown(_ range: BlockSelectionRange, in note: Note) -> Bool {
        moveRange(range, in: note, by: 1)
    }

    private static func moveRange(_ range: BlockSelectionRange, in note: Note, by offset: Int) -> Bool {
        guard canMoveRange(range, in: note, by: offset),
              let bounds = contiguousSiblingBounds(of: range, in: note) else {
            return false
        }
        var siblings = bounds.siblings

        if offset < 0 {
            let moving = siblings.remove(at: bounds.firstIndex - 1)
            siblings.insert(moving, at: bounds.lastIndex)
        } else {
            let moving = siblings.remove(at: bounds.lastIndex + 1)
            siblings.insert(moving, at: bounds.firstIndex)
        }

        for (newOrder, sibling) in siblings.enumerated() {
            sibling.order = newOrder
        }
        return true
    }

    /// Freres directs (meme parent) portant la plage, avec les index de son premier et
    /// dernier bloc AU SEIN de cette fratrie -- structure PLUTOT qu'un tuple (regle
    /// SwiftLint `large_tuple`, au plus 2 membres) pour ses 3 champs.
    private struct SiblingBounds {
        let siblings: [Block]
        let firstIndex: Int
        let lastIndex: Int
    }

    /// `nil` si la plage est vide, traverse des niveaux d'imbrication differents, ou
    /// n'est pas un segment CONTIGU de la fratrie (un frere non selectionne intercale
    /// entre le premier et le dernier bloc de la plage rendrait tout deplacement de
    /// groupe ambigu).
    private static func contiguousSiblingBounds(of range: BlockSelectionRange, in note: Note) -> SiblingBounds? {
        let ordered = orderedBlocks(of: range, in: note)
        guard let first = ordered.first, let last = ordered.last else { return nil }

        let parentID = first.parent?.id
        guard ordered.allSatisfy({ $0.parent?.id == parentID }) else { return nil }

        let siblings = BlockOrdering.siblings(of: first)
        guard let firstIndex = siblings.firstIndex(where: { $0.id == first.id }),
              let lastIndex = siblings.firstIndex(where: { $0.id == last.id }),
              lastIndex - firstIndex == ordered.count - 1 else {
            return nil
        }
        return SiblingBounds(siblings: siblings, firstIndex: firstIndex, lastIndex: lastIndex)
    }

    // MARK: - Conversion en lot (voir la documentation de tete de fichier)

    /// Convertit chaque bloc de `range` qui accepte `newType`, ignore les autres (voir
    /// la documentation de tete de fichier). Reutilise `BlockConversion.convert(_:to:)`
    /// bloc par bloc, sans dupliquer sa logique de conservation/abandon des attributs.
    public static func convertRange(_ range: BlockSelectionRange, to newType: BlockType, in note: Note) {
        for block in orderedBlocks(of: range, in: note) {
            guard BlockConversion.availableTargets(for: block).contains(newType) else { continue }
            BlockConversion.convert(block, to: newType)
        }
    }

    /// Au moins un bloc de `range` accepte-t-il UNE conversion (vers n'importe quel
    /// type) ? Utilise par l'appelant SwiftUI pour decider si le sous-menu "Convertir
    /// en..." doit proposer `BlockConversion.convertibleTypes` ou rester desactive --
    /// jamais un controle qui semble actionnable sans qu'aucun bloc de la plage n'y
    /// reponde.
    public static func hasAnyConvertibleBlock(in range: BlockSelectionRange, note: Note) -> Bool {
        orderedBlocks(of: range, in: note).contains { BlockConversion.convertibleTypes.contains($0.type) }
    }
}
