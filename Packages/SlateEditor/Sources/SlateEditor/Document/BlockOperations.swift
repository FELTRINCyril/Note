import Foundation
import SlateModel

/// Logique PURE (aucune dependance AppKit, aucun `ModelContext`) des operations
/// declenchees par le MENU de bloc (docs/05_editeur_blocs.md, sous-etape 5.4) :
/// dupliquer, supprimer, deplacer d'un cran. Memes principes que `BlockLifecycle`
/// (sous-etape 5.3) : opere directement sur le graphe `Block`/`Note` deja en memoire,
/// entierement testable sans `NSTextView` ni fenetre. `EditorController` est la SEULE
/// facade appelee par la couche SwiftUI (`BlockTreeView`) ; elle delegue tout calcul
/// ici et se contente d'appliquer le resultat (focus/selection, persistance).
///
/// ## Decisions documentees pour les cas ambigus de la spec
///
/// - **Duplication.** Copie PROFONDE : `RichText`/`BlockAttributes` sont des `struct`
///   (copiees par valeur, aucun risque de partage accidentel), et surtout tous les
///   ENFANTS du bloc sont dupliques RECURSIVEMENT -- oublier les enfants ferait
///   disparaitre silencieusement le contenu d'un item de liste imbriquee lors de sa
///   duplication. Le double est insere juste APRES l'original (`BlockOrdering.insert`,
///   qui renumerote deja `order` pour toute la fratrie).
/// - **Suppression.** Reutilise `BlockOrdering.remove(_:)` : les enfants directs du
///   bloc supprime sont PROMUS a sa place (meme choix que la sous-etape 5.3, "Retour
///   arriere" -- voir la documentation de `BlockLifecycle`), jamais supprimes en
///   cascade. Si cette suppression laisse la note SANS AUCUN bloc (dernier bloc
///   racine, sans enfant a promouvoir), un paragraphe vide est insere pour que la note
///   reste toujours editable -- le meme garde-fou que celui deja pose par
///   `BlockLifecycle.handleBackspaceAtStart` (qui empeche de supprimer le tout dernier
///   bloc PAR CE GESTE-LA) ; le menu ouvre un second chemin de suppression qui doit
///   obeir a la meme regle.
/// - **Deplacement.** Restreint aux FRERES de MEME NIVEAU (`parent` identique) : monter
///   ou descendre un bloc a TRAVERS des niveaux d'imbrication differents (ex: faire
///   sortir un item de liste de sa liste, ou l'y faire entrer) souleverait des
///   questions de conversion/reindentation non traitees avant la 5.5 (conversion de
///   type) et la Phase 10 (drag & drop visuel, qui porte le geste de reindentation
///   complet) -- voir docs/05_editeur_blocs.md, sous-etape 5.4, point 2 ("le
///   deplacement doit recalculer les `order` correctement... sinon restreins-le aux
///   freres de meme niveau et documente-le"). Aucun effet aux BORDS d'une fratrie
///   (premier bloc vers le haut, dernier vers le bas) : retourne `false` sans rien
///   modifier, l'appelant doit alors laisser le focus/la selection ou ils sont.
@MainActor
public enum BlockOperations {
    // MARK: - Duplication

    /// Duplique `block` (type, texte, attributs, enfants recursivement) et insere le
    /// double juste apres l'original. Retourne le double, pour que l'appelant puisse y
    /// deplacer le focus/la selection.
    @discardableResult
    public static func duplicate(_ block: Block) -> Block {
        let copy = deepCopy(of: block)
        BlockOrdering.insert(copy, after: block)
        return copy
    }

    private static func deepCopy(of block: Block) -> Block {
        let copy = Block(type: block.type, text: block.text, attributes: block.attributes)
        let childrenCopies = BlockOrdering.children(of: block).map(deepCopy(of:))
        for (index, child) in childrenCopies.enumerated() {
            child.parent = copy
            child.order = index
        }
        copy.children = childrenCopies
        return copy
    }

    // MARK: - Suppression (voir la documentation de tete de fichier)

    /// Supprime `block`. `note` doit etre la note porteuse de `block`, lue par
    /// l'appelant AVANT l'appel (voir `EditorController.deleteBlock(_:)`) : une fois
    /// `BlockOrdering.remove(_:)` execute, `block.note` est deja remis a `nil`.
    public static func remove(_ block: Block, from note: Note) {
        BlockOrdering.remove(block)
        guard (note.blocks ?? []).isEmpty else { return }
        let fallback = Block(type: .paragraph, text: RichText())
        fallback.note = note
        note.blocks = [fallback]
    }

    // MARK: - Deplacement parmi les freres de meme niveau

    /// Deplace `block` d'un cran vers le HAUT parmi ses freres de meme niveau.
    /// `false` (aucun effet) si `block` est deja le premier de sa fratrie.
    @discardableResult
    public static func moveUp(_ block: Block) -> Bool {
        move(block, by: -1)
    }

    /// Symmetrique de `moveUp(_:)` : un cran vers le BAS. `false` (aucun effet) si
    /// `block` est deja le dernier de sa fratrie.
    @discardableResult
    public static func moveDown(_ block: Block) -> Bool {
        move(block, by: 1)
    }

    private static func move(_ block: Block, by offset: Int) -> Bool {
        var siblings = BlockOrdering.siblings(of: block)
        guard let index = siblings.firstIndex(where: { $0.id == block.id }) else { return false }
        let targetIndex = index + offset
        guard siblings.indices.contains(targetIndex) else { return false }

        siblings.swapAt(index, targetIndex)
        for (newOrder, sibling) in siblings.enumerated() {
            sibling.order = newOrder
        }
        // Mute `order` DIRECTEMENT, sans passer par `BlockOrdering.insert`/`remove` (portee
        // volontairement restreinte aux freres de meme niveau, voir la documentation de
        // tete de fichier) : le cache de l'ordre aplati de `BlockOrdering` doit donc etre
        // invalide EXPLICITEMENT ici, sinon la navigation clavier suivante lirait un ordre
        // perime (bloc fantome silencieux, voir la documentation du cache).
        BlockOrdering.invalidateCache(for: block.note)
        return true
    }
}
