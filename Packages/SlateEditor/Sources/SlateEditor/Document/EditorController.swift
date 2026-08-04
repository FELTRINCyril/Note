import CoreGraphics
import Foundation
import SlateModel
import SlateUI
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
    public internal(set) var focusedBlockID: UUID?

    /// Plage de blocs SELECTIONNES (sous-etape 5.6), hors edition -- mutuellement
    /// exclusive avec `focusedBlockID`. Generalise `selectedBlockID` (5.3) : un bloc
    /// seul selectionne (Echap, poignee, clic) EST une plage de taille 1
    /// (`BlockSelectionRange.isSingleBlock`), le geste supplementaire (clic + Maj,
    /// glisser, Maj + fleche -- voir `extendSelection(to:)`/`extendSelectionVertically`)
    /// l'etend a plusieurs. Source UNIQUE de la selection multi-blocs : `BlockTreeView`
    /// resout `SlateBlockRangePosition` pour CHAQUE bloc via
    /// `BlockSelectionOperations.rangePositions(forOrderedIDs:)`, jamais en inspectant
    /// directement cette propriete bloc par bloc (couteux -- voir sa documentation).
    ///
    /// Depuis cette sous-etape, N'EST PLUS restreint aux blocs `.paragraph` : point 3
    /// de la tache 5.6, "trou d'accessibilite" signale par l'agent de la 5.4 (le menu de
    /// bloc n'etait atteignable au clavier que sur un paragraphe). `BlockTreeView` rend
    /// desormais l'etat `.selected`/le focus clavier pour TOUT type de bloc rendu.
    public internal(set) var blockSelectionRange: BlockSelectionRange?

    /// Convenance retro-compatible (sous-etape 5.3) : le bloc selectionne SEUL, ou
    /// `nil` si aucune selection n'est active ou si elle couvre plusieurs blocs. Calcule
    /// depuis `blockSelectionRange`, jamais stocke separement -- une seule source de
    /// verite. Conserve ce nom et ce type EXACTS pour ne pas casser les appelants/tests
    /// des sous-etapes 5.3 a 5.5 qui ne connaissent qu'une selection d'UN bloc.
    public var selectedBlockID: UUID? {
        guard let blockSelectionRange, blockSelectionRange.isSingleBlock else { return nil }
        return blockSelectionRange.anchorBlockID
    }

    /// Cadres (memes coordonnees que la `coordinateSpace` nommee partagee par
    /// `NoteDocumentView`/`BlockTreeView`) des blocs actuellement rendus a l'ecran,
    /// alimentes par une `PreferenceKey` (`BlockFramePreferenceKey`) a chaque
    /// changement de mise en page. Type PUR (`CGRect`, pas de SwiftUI) : sert
    /// uniquement a resoudre "quel bloc est sous le pointeur" pendant un glisser de
    /// selection (`continueBlockRangeDrag(pointerLocation:)`) -- ce dictionnaire est
    /// une simple donnee d'ENTREE, aucune geometrie n'est calculee ici.
    public internal(set) var blockFrames: [UUID: CGRect] = [:]

    /// Bloc ou un glisser de selection a COMMENCE (`beginBlockRangeDrag(at:)`), tant que
    /// le geste est en cours -- distinct de `blockSelectionRange.anchorBlockID` : ce
    /// dernier n'est ecrit qu'une fois la frontiere de bloc reellement franchie (spec
    /// E4, voir `continueBlockRangeDrag(pointerLocation:)`), pour que dessiner-selectionner
    /// DANS un seul bloc (selection de texte native) ne declenche jamais l'aplat de
    /// plage tant que le glisser n'en est pas sorti. Pas `private` (acces necessaire
    /// depuis l'extension `EditorController+Selection.swift`, ou vit toute la logique
    /// de selection multi-blocs -- voir sa documentation de tete de fichier pour
    /// pourquoi ce fichier est separe).
    var dragRangeAnchorBlockID: UUID?

    /// Requete de positionnement de caret en attente pour le PROCHAIN rendu du bloc
    /// `EditorCaretRequest.blockID`. Consommee une seule fois via
    /// `consumePendingCaretRequest(for:)`, jamais lue directement par les vues.
    public internal(set) var pendingCaretRequest: EditorCaretRequest?

    /// Etat du menu de commandes "/" (docs/06_slash_commandes.md, sous-etape 6.3),
    /// `nil` si aucun menu n'est ouvert. Toute la logique d'ouverture/mise a
    /// jour/fermeture/execution vit dans `EditorController+SlashMenu.swift` (voir sa
    /// documentation de tete) -- separe de ce fichier pour rester sous la limite de
    /// longueur de `CLAUDE.md` §5, meme motif exact que `EditorController+Selection.swift`.
    public internal(set) var slashMenuState: SlashMenuState?

    /// Pas `private` (acces necessaire depuis `EditorController+Selection.swift`, seul
    /// autre fichier de ce type -- voir sa documentation de tete de fichier).
    let note: Note
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
        blockSelectionRange = nil
        // Menu "/" (sous-etape 6.4, regle de fermeture "perte de focus du bloc") : un
        // gain de focus AppKit sur un AUTRE bloc que celui vise par le menu le ferme.
        // Defensif -- `noteBlockDidEndEditing(_:)` ci-dessous ferme deja le menu du bloc
        // qui PERD le focus dans le cas nominal, cette garde couvre le cas ou l'ancien
        // `NSTextView` n'a pour une raison quelconque jamais notifie sa propre perte de
        // focus avant que le nouveau ne notifie son gain.
        if let slashMenuState, slashMenuState.blockID != blockID {
            self.slashMenuState = nil
        }
    }

    public func noteBlockDidEndEditing(_ blockID: UUID) {
        guard focusedBlockID == blockID else { return }
        focusedBlockID = nil
        // Menu "/" (sous-etape 6.4, regle de fermeture "perte de focus du bloc") : voir
        // la documentation de `noteBlockDidBeginEditing(_:)` ci-dessus.
        if slashMenuState?.blockID == blockID {
            slashMenuState = nil
        }
    }

    // MARK: - Entree / Retour arriere (delegue a `BlockLifecycle`)

    /// - Returns: `true` (toujours) : Entree en edition est TOUJOURS prise en charge
    ///   par le cycle de vie de bloc en 5.3 (plus jamais le retour a la ligne natif dans
    ///   le contenu -- comportement de la 5.2, remplace ici).
    @discardableResult
    public func handleEnter(in block: Block, caretOffset: RichTextOffset) -> Bool {
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
    /// Delegue a `selectBlock(_:)` (sous-etape 5.6) : meme effet EXACT qu'avant (un seul
    /// bloc selectionne), desormais expose comme le geste GENERIQUE de selection d'un
    /// bloc unique (aussi reutilise par le clic simple hors edition, voir `BlockTreeView`).
    public func handleEscape(in block: Block) {
        selectBlock(block)
    }

    /// Selectionne `block` SEUL (plage de taille 1), hors edition -- geste generique
    /// derriere `handleEscape(in:)` (sortie d'edition) ET le clic simple sur un bloc non
    /// editable (titre, citation, item de liste, separateur -- sous-etape 5.6, point 3 :
    /// "generaliser la selection a tous les types de bloc rendus", ces types n'ayant pas
    /// de NSTextView pour offrir un geste "Echap" equivalent).
    public func selectBlock(_ block: Block) {
        focusedBlockID = nil
        blockSelectionRange = BlockSelectionRange(single: block.id)
        pendingCaretRequest = nil
    }

    /// Entree alors qu'un bloc est SELECTIONNE SEUL (pas en edition) : y rentre, caret en
    /// fin de contenu (comportement usuel d'un clic dans un bloc existant). Sans effet
    /// si plusieurs blocs sont selectionnes (`selectedBlockID` vaut alors `nil` --
    /// "rentrer en edition" n'a pas de sens pour une plage, voir la documentation de
    /// `blockSelectionRange`).
    public func handleEnterOnSelectedBlock() {
        guard let blockID = selectedBlockID else { return }
        blockSelectionRange = nil
        let request = EditorCaretRequest(blockID: blockID, placement: .end)
        applyFocus(request)
    }

    // MARK: - Zone cliquable de bas de document (spec E4 : "un clic y cree un bloc vide
    // focalise")

    /// Ajoute un paragraphe vide a la fin de la note et lui donne le focus. Fonctionne
    /// meme sur une note sans aucun bloc (cree le tout premier).
    public func appendTrailingParagraph() {
        let emptyText = RichText()
        let newBlock = Block(type: .paragraph, text: emptyText)
        if let last = BlockOrdering.flattenedBlocks(of: note).last {
            BlockOrdering.insert(newBlock, after: last)
        } else {
            newBlock.note = note
            note.blocks = [newBlock]
            // `flattenedBlocks(of:)` ci-dessus a DEJA construit et mis en cache l'ordre
            // aplati de `note` (vide, puisque la branche `else` signifie "aucun bloc
            // avant celui-ci") : cette affectation directe de `note.blocks` contourne
            // `BlockOrdering.insert` (qui invaliderait normalement le cache lui-meme),
            // donc SANS cet appel explicite le cache resterait perime a "note vide" pour
            // toujours -- exactement le bloc fantome que la documentation du cache mise
            // en garde contre (regression reelle detectee par
            // `EditorControllerTests.appendTrailingParagraphOnEmptyNote`).
            BlockOrdering.invalidateCache(for: note)
        }
        applyFocus(EditorCaretRequest(blockID: newBlock.id, placement: .offset(0)))
        persistEmptyBlockInsertion(emptyText)
    }

    // MARK: - Menu de bloc (sous-etape 5.4 : poignee -> bouton "+" et menu)

    /// Bouton "+" du chrome de bloc (spec E4) : insere un paragraphe vide juste apres
    /// `block` et lui donne le focus. POINT D'ACCROCHE POUR LA PHASE 6 : le menu `/`
    /// remplacera alors la focalisation directe d'un bloc vide par l'ouverture de ce
    /// menu sur le bloc nouvellement insere -- cette methode restera l'unique chemin de
    /// creation, seul ce qui se passe APRES l'insertion changera.
    public func insertBlockBelow(_ block: Block) {
        let emptyText = RichText()
        let newBlock = Block(type: .paragraph, text: emptyText)
        BlockOrdering.insert(newBlock, after: block)
        applyFocus(EditorCaretRequest(blockID: newBlock.id, placement: .offset(0)))
        persistEmptyBlockInsertion(emptyText)
    }

    /// Action "Dupliquer" du menu de bloc (voir `BlockOperations.duplicate(_:)` pour la
    /// copie profonde). Le double est SELECTIONNE (pas focalise en edition) : c'est
    /// l'etat le plus proche du geste "je viens d'agir sur ce bloc precis" sans
    /// pretendre y avoir deja tape du texte.
    public func duplicateBlock(_ block: Block) {
        let copy = BlockOperations.duplicate(block)
        focusedBlockID = nil
        blockSelectionRange = BlockSelectionRange(single: copy.id)
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
        let fallbackID = neighborID ?? BlockOrdering.flattenedBlocks(of: note).first?.id
        blockSelectionRange = fallbackID.map { BlockSelectionRange(single: $0) }
        pendingCaretRequest = nil
        persistStructuralChange()
    }

    /// Action "Convertir en..." du menu de bloc (sous-etape 5.5, voir `BlockConversion`
    /// pour la regle de conservation/abandon des `BlockAttributes`, le texte riche
    /// inchange, et le sort des enfants). Sans effet si `newType` ne fait pas partie de
    /// `BlockConversion.availableTargets(for: block)` -- l'appelant (menu) ne devrait de
    /// toute facon jamais proposer un type hors de cette liste. Le bloc reste
    /// SELECTIONNE apres conversion (pas focalise en edition) : coherent avec
    /// `duplicateBlock(_:)`, la meme action de menu qui ne pretend pas avoir ete
    /// declenchee par une frappe dans le contenu.
    public func convertBlock(_ block: Block, to newType: BlockType) {
        BlockConversion.convert(block, to: newType)
        focusedBlockID = nil
        blockSelectionRange = BlockSelectionRange(single: block.id)
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

    /// Pas `private` (acces necessaire depuis `EditorController+SlashMenu.swift`, qui
    /// focalise le bloc converti/nouvellement insere apres l'execution d'une commande
    /// "/" -- exactement le meme motif que `persistStructuralChange()` juste en
    /// dessous, deja ouvert pour `EditorController+Selection.swift`).
    func applyFocus(_ request: EditorCaretRequest) {
        focusedBlockID = request.blockID
        blockSelectionRange = nil
        pendingCaretRequest = request
    }

    /// Point de sauvegarde UNIQUE de toute operation structurelle (docs/05_editeur_blocs.md,
    /// sous-etape 5.3, point 7) : le MEME que celui de la 5.2 (`BlockTextCommit`), pour
    /// qu'il n'existe jamais un second chemin d'ecriture concurrent. Appele
    /// SYNCHRONEMENT (pas de debounce ici) : une insertion/fusion/split n'arrive jamais
    /// a la cadence d'une frappe de caractere, contrairement a l'ecriture de
    /// `Block.text` que `RichTextBlockView.Coordinator` debounce deja. Pas `private`
    /// (acces necessaire depuis `EditorController+Selection.swift`, dont chaque
    /// operation en lot persiste UNE SEULE FOIS pour tout le lot -- voir sa
    /// documentation de tete de fichier).
    func persistStructuralChange() {
        BlockTextCommit.flush(note: note)
        try? modelContext?.save()
    }

    /// Variante de `persistStructuralChange()` pour les DEUX SEULS appelants qui
    /// inserent un bloc de texte VIDE et rien d'autre (`appendTrailingParagraph`,
    /// `insertBlockBelow`) : voir `BlockTextCommit.flushWithoutRefreshingDerivedText(
    /// note:insertedText:)` pour la justification complete (recalculer `plainText`/
    /// `snippetText` est PROUVABLEMENT inutile ici -- un bloc vide est filtre par
    /// `Note.refreshDerivedText()`, il ne peut pas changer sa sortie). `modifiedAt` est
    /// mis a jour normalement, exactement comme `persistStructuralChange()` ; seul le
    /// recalcul du texte derive est evite. `emptyText` : le `RichText` QUI VIENT D'ETRE
    /// INSERE par l'appelant, transmis pour que l'assertion defensive de
    /// `flushWithoutRefreshingDerivedText` puisse verifier qu'il est bien vide.
    private func persistEmptyBlockInsertion(_ emptyText: RichText) {
        BlockTextCommit.flushWithoutRefreshingDerivedText(note: note, insertedText: emptyText)
        try? modelContext?.save()
    }
}
