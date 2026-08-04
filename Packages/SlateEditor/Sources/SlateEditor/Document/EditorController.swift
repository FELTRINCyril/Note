import CoreGraphics
import Foundation
import SlateModel
import SwiftData

/// Coordinateur `@Observable` du cycle de vie des blocs au clavier (docs/05_editeur_blocs.md,
/// sous-etape 5.3) : focus d'edition, selection de bloc entier, insertion/fusion/
/// suppression/split, navigation haut/bas -- et le point de sauvegarde UNIQUE de toute
/// operation structurelle (voir `persistStructuralChange()`).
///
/// ## Pourquoi cette logique est testable HORS AppKit
/// `EditorController` ne connait ni `NSTextView` ni `NSView` : chaque methode publique
/// prend en entree un `Block` et des valeurs simples (`Int`, `CGFloat`) deja extraites
/// par la couche AppKit (`RichTextEditingTextView`/son `Coordinator`), et delegue le
/// calcul reel a `BlockLifecycle` (statique, pur, sans AppKit) et `BlockOrdering`. Le
/// resultat est un `EditorCaretRequest`, lui aussi un type pur. La couche AppKit ne fait
/// qu'APPELER ces methodes puis CONSOMMER `pendingCaretRequest` pour positionner
/// reellement le curseur (`RichTextEditingTextView.applyCaretPlacement(_:)`) -- elle
/// n'implemente elle-meme AUCUNE regle de cycle de vie. C'est cette separation qui
/// permet aux tests de `EditorControllerTests`/`BlockLifecycleTests` de construire des
/// `Note`/`Block` en memoire (sans `ModelContext`, sans fenetre) et de verifier
/// directement le graphe de blocs resultant et le `EditorCaretRequest` retourne.
@MainActor
@Observable
public final class EditorController {
    /// Bloc actuellement en EDITION (caret dans son `NSTextView`). `nil` si aucun bloc
    /// n'est en cours d'edition.
    public private(set) var focusedBlockID: UUID?

    /// Bloc SELECTIONNE en entier (spec E4 : "Echap sort de l'edition et selectionne le
    /// bloc entier"), hors edition. Mutuellement exclusif avec `focusedBlockID` --
    /// restreint aux blocs `.paragraph`, seul type reellement editable a ce stade de la
    /// Phase 5 (voir `BlockContentRouterView`) : selectionner un bloc dont l'edition
    /// n'existe pas encore n'aurait pas de geste "Entree" cible a offrir.
    public private(set) var selectedBlockID: UUID?

    /// Requete de positionnement de caret en attente pour le PROCHAIN rendu du bloc
    /// `EditorCaretRequest.blockID`. Consommee une seule fois via
    /// `consumePendingCaretRequest(for:)`, jamais lue directement par les vues.
    public private(set) var pendingCaretRequest: EditorCaretRequest?

    private let note: Note
    private var modelContext: ModelContext?

    public init(note: Note, modelContext: ModelContext? = nil) {
        self.note = note
        self.modelContext = modelContext
    }

    /// A appeler a chaque rendu (voir `RichTextBlockView`/`NoteDocumentView`) : le
    /// `ModelContext` n'est disponible que via `@Environment`, jamais a l'`init`.
    public func updateModelContext(_ modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    /// Retire et retourne la requete de caret en attente SI elle vise `blockID`, sinon
    /// `nil` sans effet de bord -- une seule vue peut consommer une requete donnee,
    /// jamais deux.
    @discardableResult
    public func consumePendingCaretRequest(for blockID: UUID) -> EditorCaretRequest? {
        guard let request = pendingCaretRequest, request.blockID == blockID else { return nil }
        pendingCaretRequest = nil
        return request
    }

    // MARK: - Focus (appele par `RichTextBlockView.Coordinator` sur gain/perte reelle
    // de premier repondant AppKit -- ex: clic direct dans un bloc, Tab)

    public func noteBlockDidBeginEditing(_ blockID: UUID) {
        focusedBlockID = blockID
        selectedBlockID = nil
    }

    public func noteBlockDidEndEditing(_ blockID: UUID) {
        guard focusedBlockID == blockID else { return }
        focusedBlockID = nil
    }

    // MARK: - Entree / Retour arriere (delegue a `BlockLifecycle`)

    /// - Returns: `true` (toujours) : Entree en edition est TOUJOURS prise en charge
    ///   par le cycle de vie de bloc en 5.3 (plus jamais le retour a la ligne natif dans
    ///   le contenu -- comportement de la 5.2, remplace ici).
    @discardableResult
    public func handleEnter(in block: Block, caretOffset: Int) -> Bool {
        let request = BlockLifecycle.handleEnter(in: block, caretOffset: caretOffset)
        applyFocus(request)
        persistStructuralChange()
        return true
    }

    /// - Returns: `true` si une operation a eu lieu (fusion/suppression), `false` si
    ///   `block` est le premier bloc de la note (rien a faire, voir `BlockLifecycle`) --
    ///   dans ce cas l'appelant doit laisser AppKit executer son `deleteBackward` natif
    ///   par defaut (qui ne fera rien non plus, le caret etant deja en position 0).
    @discardableResult
    public func handleBackspaceAtBlockStart(_ block: Block) -> Bool {
        guard let request = BlockLifecycle.handleBackspaceAtStart(in: block) else { return false }
        applyFocus(request)
        persistStructuralChange()
        return true
    }

    // MARK: - Navigation haut/bas (aucune mutation du modele : lecture seule)

    /// - Returns: `true` si un bloc voisin existe et a recu le focus, `false` en bord de
    ///   document (premier/dernier bloc) -- l'appelant doit alors laisser AppKit garder
    ///   le caret ou il est.
    @discardableResult
    public func handleMoveUp(from block: Block, visualColumnX: CGFloat) -> Bool {
        guard let target = BlockOrdering.block(before: block) else { return false }
        let request = EditorCaretRequest(blockID: target.id, placement: .visualColumn(x: visualColumnX, edge: .bottom))
        applyFocus(request)
        return true
    }

    @discardableResult
    public func handleMoveDown(from block: Block, visualColumnX: CGFloat) -> Bool {
        guard let target = BlockOrdering.block(after: block) else { return false }
        let request = EditorCaretRequest(blockID: target.id, placement: .visualColumn(x: visualColumnX, edge: .top))
        applyFocus(request)
        return true
    }

    // MARK: - Echap / Entree hors edition (spec E4, "Caret, selection, depot")

    /// Echap en cours d'edition : sort de l'edition, selectionne `block` en entier.
    public func handleEscape(in block: Block) {
        focusedBlockID = nil
        selectedBlockID = block.id
    }

    /// Entree alors qu'un bloc est SELECTIONNE (pas en edition) : y rentre, caret en
    /// fin de contenu (comportement usuel d'un clic dans un bloc existant).
    public func handleEnterOnSelectedBlock() {
        guard let blockID = selectedBlockID else { return }
        selectedBlockID = nil
        let request = EditorCaretRequest(blockID: blockID, placement: .end)
        applyFocus(request)
    }

    // MARK: - Zone cliquable de bas de document (spec E4 : "un clic y cree un bloc vide
    // focalise")

    /// Ajoute un paragraphe vide a la fin de la note et lui donne le focus. Fonctionne
    /// meme sur une note sans aucun bloc (cree le tout premier).
    public func appendTrailingParagraph() {
        let newBlock = Block(type: .paragraph, text: RichText())
        if let last = BlockOrdering.flattenedBlocks(of: note).last {
            BlockOrdering.insert(newBlock, after: last)
        } else {
            newBlock.note = note
            note.blocks = [newBlock]
        }
        applyFocus(EditorCaretRequest(blockID: newBlock.id, placement: .offset(0)))
        persistStructuralChange()
    }

    // MARK: - Menu de bloc (sous-etape 5.4 : poignee -> bouton "+" et menu)

    /// Bouton "+" du chrome de bloc (spec E4) : insere un paragraphe vide juste apres
    /// `block` et lui donne le focus. POINT D'ACCROCHE POUR LA PHASE 6 : le menu `/`
    /// remplacera alors la focalisation directe d'un bloc vide par l'ouverture de ce
    /// menu sur le bloc nouvellement insere -- cette methode restera l'unique chemin de
    /// creation, seul ce qui se passe APRES l'insertion changera.
    public func insertBlockBelow(_ block: Block) {
        let newBlock = Block(type: .paragraph, text: RichText())
        BlockOrdering.insert(newBlock, after: block)
        applyFocus(EditorCaretRequest(blockID: newBlock.id, placement: .offset(0)))
        persistStructuralChange()
    }

    /// Action "Dupliquer" du menu de bloc (voir `BlockOperations.duplicate(_:)` pour la
    /// copie profonde). Le double est SELECTIONNE (pas focalise en edition) : c'est
    /// l'etat le plus proche du geste "je viens d'agir sur ce bloc precis" sans
    /// pretendre y avoir deja tape du texte.
    public func duplicateBlock(_ block: Block) {
        let copy = BlockOperations.duplicate(block)
        focusedBlockID = nil
        selectedBlockID = copy.id
        pendingCaretRequest = nil
        persistStructuralChange()
    }

    /// Action "Supprimer" du menu de bloc (voir `BlockOperations.remove(_:from:)` pour
    /// le sort des enfants et la garantie de non-vacuite de la note). Selectionne le
    /// bloc voisin le plus proche (suivant, sinon precedent, sinon le premier bloc
    /// restant -- necessairement le paragraphe de secours si `block` etait le dernier)
    /// pour que l'utilisateur retrouve immediatement un point d'ancrage clavier.
    public func deleteBlock(_ block: Block) {
        guard let note = block.note else { return }
        let neighborID = BlockOrdering.block(after: block)?.id ?? BlockOrdering.block(before: block)?.id

        BlockOperations.remove(block, from: note)

        if focusedBlockID == block.id { focusedBlockID = nil }
        selectedBlockID = neighborID ?? BlockOrdering.flattenedBlocks(of: note).first?.id
        pendingCaretRequest = nil
        persistStructuralChange()
    }

    /// Action "Deplacer vers le haut" du menu de bloc (voir `BlockOperations.moveUp(_:)`
    /// pour la portee -- freres de meme niveau uniquement). `false` sans effet si
    /// `block` est deja en tete de sa fratrie.
    @discardableResult
    public func moveBlockUp(_ block: Block) -> Bool {
        guard BlockOperations.moveUp(block) else { return false }
        persistStructuralChange()
        return true
    }

    /// Symmetrique de `moveBlockUp(_:)` : un cran vers le bas.
    @discardableResult
    public func moveBlockDown(_ block: Block) -> Bool {
        guard BlockOperations.moveDown(block) else { return false }
        persistStructuralChange()
        return true
    }

    // MARK: - Application interne

    private func applyFocus(_ request: EditorCaretRequest) {
        focusedBlockID = request.blockID
        selectedBlockID = nil
        pendingCaretRequest = request
    }

    /// Point de sauvegarde UNIQUE de toute operation structurelle (docs/05_editeur_blocs.md,
    /// sous-etape 5.3, point 7) : le MEME que celui de la 5.2 (`BlockTextCommit`), pour
    /// qu'il n'existe jamais un second chemin d'ecriture concurrent. Appele
    /// SYNCHRONEMENT (pas de debounce ici) : une insertion/fusion/split n'arrive jamais
    /// a la cadence d'une frappe de caractere, contrairement a l'ecriture de
    /// `Block.text` que `RichTextBlockView.Coordinator` debounce deja.
    private func persistStructuralChange() {
        BlockTextCommit.flush(note: note)
        try? modelContext?.save()
    }
}
