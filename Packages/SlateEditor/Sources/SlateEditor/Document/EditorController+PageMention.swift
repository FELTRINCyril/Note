import Foundation
import SlateModel
import SwiftData

/// Logique du selecteur de page "@"/"[[" (docs/16_liens_internes.md) : detection
/// d'ouverture, mise a jour de la requete a chaque frappe, navigation clavier,
/// execution (insertion d'un lien vers une note existante, ou creation d'une note a la
/// volee). Meme structure de fichier que `EditorController+SlashMenu.swift` (voir sa
/// documentation de tete pour la justification generale : separation par limite de
/// longueur de fichier, testabilite hors AppKit, seul point de contact
/// `RichTextEditingRepresentable.Coordinator`).
///
/// ## Deux declencheurs, un seul etat
/// `@` et `[[` ouvrent tous deux ce selecteur (`detectOpening`) -- `PageMentionState.
/// anchorText` retient LEQUEL a ete tape, pour que l'execution retire exactement le bon
/// nombre de caracteres (1 pour "@", 2 pour "[[").
///
/// ## Pas de fermeture sur "aucun resultat", contrairement au menu "/"
/// Voir `PageMentionFilter`, section "Pas de fermeture sur 'aucun resultat'" : zero
/// note correspondante est l'etat NORMAL qui fait apparaitre "Creer la page <query>"
/// (docs/16, critere d'acceptation). La seule regle de fermeture automatique
/// conservee est donc "requete entierement blanche" (memes raisons que le "/" : un
/// espace tape juste apres, ex. une adresse mail "cyril@ gmail.com", ne doit pas
/// laisser le selecteur ouvert indefiniment).
///
/// ## Insertion : bloc de STRUCTURE, jamais de texte inline
/// `pageLink` est un `BlockType` a part entiere (docs/16 : "Sous-pages : une note peut
/// contenir un bloc pageLink"), pas un attribut de texte inline -- exactement comme
/// `.divider`/`.table` (Phase 6) : ni `RichText` propre, ni caret. L'execution suit
/// donc le meme patron que `executeDividerCommand`/`executeTableCommand`
/// (`EditorController+SlashMenu.swift`) : le bloc courant accueille le lien EN PLACE
/// s'il ne reste rien d'autre que le declencheur/la requete une fois retires, sinon un
/// nouveau bloc `pageLink` est insere en dessous ; un paragraphe vide est TOUJOURS
/// insere apres et recoit le focus.
extension EditorController {
    /// Jeton d'identifiant de l'entree "Creer la page <query>" du selecteur -- distinct
    /// de tout `UUID.uuidString` reel (un `UUID` ne produit jamais cette forme).
    static let pageMentionCreateSentinel = "page-mention.create-new"

    // MARK: - Detection d'ouverture / mise a jour de la requete

    /// A appeler par la couche AppKit a CHAQUE frappe ET a chaque deplacement de caret
    /// dans `block` -- meme contrat que `updateSlashMenuState(for:plainText:caretOffset:)`.
    /// Ne fait jamais rien tant qu'un menu "/" est ouvert pour ce meme bloc (priorite au
    /// "/", qui a l'exclusivite du clavier pendant son ouverture -- voir
    /// `RichTextEditingTextView`, ou les deux selecteurs sont interroges dans cet ordre).
    public func updatePageMentionState(for block: Block, plainText: String, caretOffset: RichTextOffset) {
        guard slashMenuState == nil else {
            if pageMentionState?.blockID == block.id {
                pageMentionState = nil
            }
            return
        }

        if let state = pageMentionState, state.blockID == block.id {
            guard let newQuery = Self.recomputedPageMentionQuery(
                for: state, plainText: plainText, caretOffset: caretOffset
            ) else {
                pageMentionState = nil
                return
            }
            var updated = state
            updated.query = newQuery
            updated.selectedItemID = clampedPageMentionSelection(state.selectedItemID, forQuery: newQuery)
            pageMentionState = updated
            return
        }

        guard pageMentionState == nil else { return }
        guard let opened = Self.detectPageMentionOpening(plainText: plainText, caretOffset: caretOffset, blockID: block.id)
        else { return }
        var state = opened
        state.selectedItemID = clampedPageMentionSelection(nil, forQuery: state.query)
        pageMentionState = state
    }

    /// Ferme le selecteur inconditionnellement -- meme role que `closeSlashMenu()`.
    public func closePageMention() {
        pageMentionState = nil
    }

    /// `@` ou `[[` vient-il d'etre tape, jamais au milieu d'un mot (meme regle que le
    /// "/" : sinon une adresse mail comme "cyril@gemaddis" ouvrirait le selecteur a
    /// chaque caractere tape apres le "@" central) ?
    private static func detectPageMentionOpening(
        plainText: String, caretOffset: RichTextOffset, blockID: UUID
    ) -> PageMentionState? {
        let characters = Array(plainText)
        let caret = max(0, min(caretOffset.characters, characters.count))
        guard caret >= 1 else { return nil }

        if characters[caret - 1] == "@" {
            let anchor = caret - 1
            guard anchor == 0 || characters[anchor - 1].isWhitespace else { return nil }
            return PageMentionState(
                blockID: blockID, anchorOffset: RichTextOffset(characters: anchor), anchorText: "@",
                query: "", selectedItemID: nil
            )
        }

        if caret >= 2, characters[caret - 1] == "[", characters[caret - 2] == "[" {
            let anchor = caret - 2
            guard anchor == 0 || characters[anchor - 1].isWhitespace else { return nil }
            return PageMentionState(
                blockID: blockID, anchorOffset: RichTextOffset(characters: anchor), anchorText: "[[",
                query: "", selectedItemID: nil
            )
        }

        return nil
    }

    /// Recalcule la requete d'un selecteur DEJA ouvert, ou `nil` si l'une des regles de
    /// fermeture s'applique : le declencheur a l'`anchorOffset` a disparu, le caret est
    /// revenu au declencheur ou avant lui, le caret deborde du texte (defensif), ou la
    /// requete est ENTIEREMENT blanche -- voir la documentation de tete de fichier pour
    /// pourquoi AUCUNE autre regle de fermeture (notamment "zero resultat") ne
    /// s'applique ici, contrairement au menu "/".
    private static func recomputedPageMentionQuery(
        for state: PageMentionState, plainText: String, caretOffset: RichTextOffset
    ) -> String? {
        let characters = Array(plainText)
        let anchor = state.anchorOffset.characters
        let anchorEnd = anchor + state.anchorText.count
        guard anchorEnd <= characters.count, String(characters[anchor..<anchorEnd]) == state.anchorText else {
            return nil
        }

        let caret = caretOffset.characters
        guard caret >= anchorEnd, caret <= characters.count else { return nil }

        let queryCharacters = characters[anchorEnd..<caret]
        let isEntirelyWhitespace = !queryCharacters.isEmpty && queryCharacters.allSatisfy(\.isWhitespace)
        guard !isEntirelyWhitespace else { return nil }
        return String(queryCharacters)
    }

    // MARK: - Navigation clavier

    /// Fleche haut/bas, menu ouvert : deplace `selectedItemID` d'un pas dans la liste
    /// affichee courante (notes filtrees, plus l'entree "Creer..." si elle est
    /// affichee), en bouclant en bout de liste -- meme comportement que
    /// `moveSlashMenuSelection(_:in:)`.
    @discardableResult
    public func movePageMentionSelection(_ direction: BlockSelectionDirection, in block: Block) -> Bool {
        guard var state = pageMentionState, state.blockID == block.id else { return false }
        let ids = pageMentionDisplayedItemIDs(forQuery: state.query)
        guard !ids.isEmpty else { return true }

        let currentIndex = state.selectedItemID.flatMap { ids.firstIndex(of: $0) }
        let nextIndex: Int
        switch direction {
        case .up:
            nextIndex = currentIndex.map { $0 == 0 ? ids.count - 1 : $0 - 1 } ?? ids.count - 1
        case .down:
            nextIndex = currentIndex.map { $0 == ids.count - 1 ? 0 : $0 + 1 } ?? 0
        }
        state.selectedItemID = ids[nextIndex]
        pageMentionState = state
        return true
    }

    /// Survol souris : meme role que `hoverSlashMenuItem(_:)`.
    public func hoverPageMentionItem(_ itemID: String) {
        guard var state = pageMentionState else { return }
        guard pageMentionDisplayedItemIDs(forQuery: state.query).contains(itemID) else { return }
        state.selectedItemID = itemID
        pageMentionState = state
    }

    // MARK: - Entree / Echap

    /// Entree, selecteur ouvert pour `block` : insere le lien vers la note mise en
    /// avant, ou cree la page si l'entree "Creer..." est mise en avant. `false` si
    /// aucun selecteur n'est ouvert pour `block`. `true` sinon, meme si aucune entree
    /// n'est mise en avant (requete tout juste ouverte, liste encore vide) -- l'Entree
    /// est alors simplement consommee, jamais laissee scinder le bloc.
    @discardableResult
    public func handlePageMentionReturn(in block: Block) -> Bool {
        guard let state = pageMentionState, state.blockID == block.id else { return false }
        guard let selectedItemID = state.selectedItemID else { return true }
        executePageMentionSelection(selectedItemID, in: block, state: state)
        return true
    }

    /// Echap, selecteur ouvert pour `block` : ferme le selecteur SEUL. Meme regle que
    /// `handleSlashMenuEscape(in:)`.
    @discardableResult
    public func handlePageMentionEscape(in block: Block) -> Bool {
        guard let state = pageMentionState, state.blockID == block.id else { return false }
        pageMentionState = nil
        return true
    }

    /// Clic sur une ligne du selecteur : execute TOUJOURS l'entree cliquee. Meme regle
    /// que `confirmSlashMenuCommand(_:in:)`.
    public func confirmPageMentionSelection(_ itemID: String, in block: Block) {
        guard let state = pageMentionState, state.blockID == block.id else { return }
        guard pageMentionDisplayedItemIDs(forQuery: state.query).contains(itemID) else { return }
        executePageMentionSelection(itemID, in: block, state: state)
    }

    // MARK: - Filtrage (expose pour la vue overlay)

    /// Notes correspondant a la requete du selecteur OUVERT pour `block`, ou vide si
    /// aucun selecteur n'est ouvert pour ce bloc precis -- meme role que
    /// `slashMenuMatches(for:)`.
    public func pageMentionMatches(for block: Block) -> [NoteMentionMatch] {
        guard let state = pageMentionState, state.blockID == block.id else { return [] }
        return pageMentionMatches(forQuery: state.query)
    }

    /// Vrai si l'entree "Creer la page <requete>" doit etre proposee pour `block` :
    /// requete non vide ET aucune note ne correspond (docs/16 : "si aucun resultat").
    public func shouldOfferPageMentionCreation(for block: Block) -> Bool {
        guard let state = pageMentionState, state.blockID == block.id else { return false }
        let trimmed = state.query.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && pageMentionMatches(forQuery: state.query).isEmpty
    }

    private func pageMentionMatches(forQuery query: String) -> [NoteMentionMatch] {
        PageMentionFilter.match(query: query, in: pageMentionCandidates())
    }

    /// Toutes les notes proposables : exclut la note EN COURS D'EDITION (se lier a
    /// soi-meme n'a pas de sens) et la corbeille (une note en cours de suppression ne
    /// doit pas etre une cible de nouveau lien).
    private func pageMentionCandidates() -> [NoteMentionCandidate] {
        guard let modelContext else { return [] }
        let predicate = #Predicate<Note> { !$0.isTrashed }
        guard let notes = try? modelContext.fetch(FetchDescriptor<Note>(predicate: predicate)) else { return [] }
        let currentNoteID = note.id
        return notes.filter { $0.id != currentNoteID }.map { NoteMentionCandidate(id: $0.id, title: $0.title) }
    }

    /// Identifiants, DANS L'ORDRE D'AFFICHAGE, de toutes les entrees du selecteur pour
    /// `query` : les notes filtrees, puis l'entree "Creer..." si elle doit etre
    /// affichee (voir `shouldOfferPageMentionCreation(for:)`, reimplemente ici sur une
    /// requete brute plutot que sur un bloc -- meme filtre, applique aux DEUX memes
    /// points d'entree que `SlashCommandFilter`).
    private func pageMentionDisplayedItemIDs(forQuery query: String) -> [String] {
        let matches = pageMentionMatches(forQuery: query)
        var ids = matches.map { $0.candidate.id.uuidString }
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if matches.isEmpty, !trimmed.isEmpty {
            ids.append(Self.pageMentionCreateSentinel)
        }
        return ids
    }

    private func clampedPageMentionSelection(_ currentID: String?, forQuery query: String) -> String? {
        let ids = pageMentionDisplayedItemIDs(forQuery: query)
        if let currentID, ids.contains(currentID) { return currentID }
        return ids.first
    }

    // MARK: - Execution

    private func executePageMentionSelection(_ itemID: String, in block: Block, state: PageMentionState) {
        if itemID == Self.pageMentionCreateSentinel {
            let title = state.query.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty else { return }
            executeCreatePageMention(title: title, in: block, state: state)
        } else if let noteID = UUID(uuidString: itemID) {
            executeInsertPageLinkMention(linkedNoteID: noteID, in: block, state: state)
        }
    }

    /// Insere un lien vers une note DEJA EXISTANTE (`noteID`).
    private func executeInsertPageLinkMention(linkedNoteID: UUID, in block: Block, state: PageMentionState) {
        removePageMentionAnchorText(in: block, state: state)
        insertPageLinkBlock(linkedNoteID: linkedNoteID, replacingOrFollowing: block)
        pageMentionState = nil
        persistStructuralChange()
    }

    /// Cree une nouvelle note titree `title` (dans le meme dossier que la note en
    /// cours d'edition, `nil` si elle n'en a pas), puis insere un lien vers elle --
    /// docs/16 : "Creer la page 'X' si aucun resultat -> cree une sous-page et insere
    /// le lien".
    private func executeCreatePageMention(title: String, in block: Block, state: PageMentionState) {
        guard let modelContext else { pageMentionState = nil; return }
        removePageMentionAnchorText(in: block, state: state)

        let newNote = Note(title: title, folder: note.folder)
        newNote.refreshDerivedText()
        modelContext.insert(newNote)

        insertPageLinkBlock(linkedNoteID: newNote.id, replacingOrFollowing: block)
        pageMentionState = nil
        persistStructuralChange()
    }

    /// Retire le declencheur ("@"/"[[") et la requete tapee du texte de `block` --
    /// jamais en reconstruisant `RichText` depuis une `String`, meme motif que
    /// `executeSlashCommand` (`EditorController+SlashMenu.swift`) : preserve tout
    /// formatage inline deja present ailleurs dans le bloc.
    private func removePageMentionAnchorText(in block: Block, state: PageMentionState) {
        let currentText = block.text ?? RichText()
        let removalRange = RichTextRange(
            lowerBound: state.anchorOffset,
            upperBound: RichTextOffset(
                characters: state.anchorOffset.characters + state.anchorText.count + state.query.count
            )
        )
        block.text = currentText.removingCharacters(in: removalRange)
    }

    /// Place un bloc `pageLink` vers `linkedNoteID` : EN PLACE de `block` si son texte
    /// restant (apres retrait du declencheur/de la requete) est vide, sinon comme
    /// nouveau bloc juste en dessous -- meme patron que `executeDividerCommand`
    /// (`EditorController+SlashMenu.swift`), voir la documentation de tete de fichier.
    /// Un paragraphe vide est TOUJOURS insere apres et recoit le focus : `.pageLink` n'a
    /// pas de `NSTextView` propre a focaliser (voir `BlockRenderKind.pageLink`).
    private func insertPageLinkBlock(linkedNoteID: UUID, replacingOrFollowing block: Block) {
        let leftoverIsEmpty = (block.text ?? RichText()).isEmpty
        var attributes = BlockAttributes()
        attributes.linkedNoteID = linkedNoteID

        let pageLinkBlock: Block
        if leftoverIsEmpty {
            block.attributes = attributes
            block.type = .pageLink
            block.text = nil
            pageLinkBlock = block
        } else {
            let newBlock = Block(type: .pageLink, attributes: attributes)
            BlockOrdering.insert(newBlock, after: block)
            pageLinkBlock = newBlock
        }

        let trailingParagraph = Block(type: .paragraph, text: RichText())
        BlockOrdering.insert(trailingParagraph, after: pageLinkBlock)
        applyFocus(EditorCaretRequest(blockID: trailingParagraph.id, placement: .offset(0)))
    }
}
