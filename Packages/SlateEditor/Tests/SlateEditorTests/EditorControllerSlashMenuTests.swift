import Foundation
import SlateModel
import Testing

@testable import SlateEditor

/// Menu de commandes "/" (docs/06_slash_commandes.md, sous-etapes 6.3/6.4) : ouverture,
/// mise a jour de la requete, fermeture, navigation clavier. L'execution des commandes
/// (sous-etape 6.6) est couverte par `EditorControllerSlashMenuExecutionTests`, extraite
/// dans son propre fichier pour rester sous la limite de longueur de `CLAUDE.md` §5.
///
/// Ces tests n'instancient NI `NSTextView` NI `ModelContext`, exactement comme le reste
/// de `EditorControllerTests` (voir sa documentation de tete, "pourquoi cette logique
/// est testable hors AppKit") -- `updateSlashMenuState(for:plainText:caretOffset:)`
/// recoit directement les valeurs qu'une frappe/un deplacement de caret produirait,
/// sans jamais traverser AppKit.
@MainActor
@Suite("EditorController.SlashMenu")
struct EditorControllerSlashMenuTests {
    // MARK: - Ouverture (sous-etape 6.4)

    @Test("Le / tape en tout debut de bloc ouvre le menu, requete vide")
    func slashAtBlockStartOpensMenu() {
        let fixture = makeNote(text: "")
        let block = fixture.block
        let controller = fixture.controller

        controller.updateSlashMenuState(for: block, plainText: "/", caretOffset: 1)

        #expect(controller.slashMenuState?.blockID == block.id)
        #expect(controller.slashMenuState?.query.isEmpty == true)
    }

    @Test("Le / precede d'un espace ouvre le menu")
    func slashAfterWhitespaceOpensMenu() {
        let fixture = makeNote(text: "")
        let block = fixture.block
        let controller = fixture.controller

        controller.updateSlashMenuState(for: block, plainText: "Hello /", caretOffset: 7)

        #expect(controller.slashMenuState != nil)
    }

    @Test("Le / au milieu d'un mot ne doit JAMAIS ouvrir le menu (URL, et/ou...)")
    func slashInsideWordDoesNotOpenMenu() {
        let fixture = makeNote(text: "")
        let block = fixture.block
        let controller = fixture.controller

        controller.updateSlashMenuState(for: block, plainText: "Hello/World", caretOffset: 6)

        #expect(controller.slashMenuState == nil)
    }

    // MARK: - Mise a jour de la requete

    @Test("La requete se met a jour a mesure que le caret avance apres le /")
    func queryUpdatesAsCaretAdvances() {
        let fixture = makeNote(text: "")
        let block = fixture.block
        let controller = fixture.controller
        controller.updateSlashMenuState(for: block, plainText: "/", caretOffset: 1)

        controller.updateSlashMenuState(for: block, plainText: "/tit", caretOffset: 4)

        #expect(controller.slashMenuState?.query == "tit")
    }

    // MARK: - Fermeture (sous-etape 6.4)

    @Test("Fermeture : le / a ete supprime")
    func closesWhenSlashIsDeleted() {
        let fixture = makeNote(text: "")
        let block = fixture.block
        let controller = fixture.controller
        controller.updateSlashMenuState(for: block, plainText: "/tit", caretOffset: 4)

        controller.updateSlashMenuState(for: block, plainText: "tit", caretOffset: 3)

        #expect(controller.slashMenuState == nil)
    }

    @Test("Fermeture : le caret est revenu au / ou avant lui")
    func closesWhenCaretMovesBeforeAnchor() {
        let fixture = makeNote(text: "")
        let block = fixture.block
        let controller = fixture.controller
        controller.updateSlashMenuState(for: block, plainText: "/tit", caretOffset: 4)

        controller.updateSlashMenuState(for: block, plainText: "/tit", caretOffset: 0)

        #expect(controller.slashMenuState == nil)
    }

    @Test("Fermeture : un espace qui amene la requete a ZERO resultat ferme le menu")
    func closesWhenSpaceIsTypedInQueryWithNoMatches() {
        let fixture = makeNote(text: "")
        let block = fixture.block
        let controller = fixture.controller
        controller.updateSlashMenuState(for: block, plainText: "/foo", caretOffset: 4)

        controller.updateSlashMenuState(for: block, plainText: "/foo ", caretOffset: 5)

        #expect(controller.slashMenuState == nil)
    }

    @Test("Fermeture : une espace tapee IMMEDIATEMENT apres le / ferme le menu (requete vide)")
    func closesWhenSpaceTypedImmediatelyAfterSlash() {
        let fixture = makeNote(text: "")
        let block = fixture.block
        let controller = fixture.controller
        controller.updateSlashMenuState(for: block, plainText: "/", caretOffset: 1)
        #expect(controller.slashMenuState != nil)

        controller.updateSlashMenuState(for: block, plainText: "/ ", caretOffset: 2)

        #expect(controller.slashMenuState == nil)
    }

    @Test("Fermeture : une espace qui amene une requete de prose a zero resultat ferme le menu")
    func closesOnSpaceWhenProseQueryHasNoMatches() {
        let fixture = makeNote(text: "")
        let block = fixture.block
        let controller = fixture.controller
        controller.updateSlashMenuState(for: block, plainText: "/", caretOffset: 1)
        controller.updateSlashMenuState(for: block, plainText: "/zzzzzz", caretOffset: 7)
        #expect(controller.slashMenuState != nil) // sans espace, reste ouvert (etat vide) -- voir plus bas

        controller.updateSlashMenuState(for: block, plainText: "/zzzzzz ", caretOffset: 8)

        #expect(controller.slashMenuState == nil)
    }

    @Test("Une espace qui laisse au moins une commande correspondante GARDE le menu ouvert (/titre 1)")
    func spaceInMultiWordQueryKeepsMenuOpenWhenStillMatching() {
        let fixture = makeNote(text: "")
        let block = fixture.block
        let controller = fixture.controller
        controller.updateSlashMenuState(for: block, plainText: "/", caretOffset: 1)
        controller.updateSlashMenuState(for: block, plainText: "/titre", caretOffset: 6)
        controller.updateSlashMenuState(for: block, plainText: "/titre ", caretOffset: 7)
        #expect(controller.slashMenuState != nil) // "titre " reste prefixe de "Titre 1".."Titre 6"

        controller.updateSlashMenuState(for: block, plainText: "/titre 1", caretOffset: 8)

        #expect(controller.slashMenuState != nil)
        #expect(controller.slashMenuState?.query == "titre 1")
        let matches = SlashCommandFilter.match(query: "titre 1", in: SlashCommandRegistry.allCommands)
        #expect(matches.contains { $0.command.id == "heading1" })
    }

    @Test("handleSlashMenuEscape ferme le menu SEUL, sans selectionner le bloc entier")
    func escapeClosesMenuWithoutSelectingBlock() {
        let fixture = makeNote(text: "")
        let block = fixture.block
        let controller = fixture.controller
        controller.noteBlockDidBeginEditing(block.id)
        controller.updateSlashMenuState(for: block, plainText: "/", caretOffset: 1)

        let handled = controller.handleSlashMenuEscape(in: block)

        #expect(handled == true)
        #expect(controller.slashMenuState == nil)
        #expect(controller.focusedBlockID == block.id)
        #expect(controller.selectedBlockID == nil)
    }

    @Test("handleSlashMenuEscape retourne false si aucun menu n'est ouvert pour ce bloc")
    func escapeReturnsFalseWhenNoMenuOpen() {
        let fixture = makeNote(text: "")
        let block = fixture.block
        let controller = fixture.controller

        #expect(controller.handleSlashMenuEscape(in: block) == false)
    }

    @Test("Perte de focus du bloc ferme le menu")
    func losingFocusClosesMenu() {
        let fixture = makeNote(text: "")
        let block = fixture.block
        let controller = fixture.controller
        controller.noteBlockDidBeginEditing(block.id)
        controller.updateSlashMenuState(for: block, plainText: "/", caretOffset: 1)

        controller.noteBlockDidEndEditing(block.id)

        #expect(controller.slashMenuState == nil)
    }

    @Test("Le focus gagne par un AUTRE bloc ferme le menu du bloc precedent")
    func gainingFocusOnAnotherBlockClosesMenu() {
        let note = Note(title: "Test")
        let first = Block(order: 0, type: .paragraph, text: RichText(plainText: "/"), note: note)
        let second = Block(order: 1, type: .paragraph, text: RichText(plainText: "Deux"), note: note)
        note.blocks = [first, second]
        let controller = EditorController(note: note)
        controller.noteBlockDidBeginEditing(first.id)
        controller.updateSlashMenuState(for: first, plainText: "/", caretOffset: 1)
        #expect(controller.slashMenuState != nil)

        controller.noteBlockDidBeginEditing(second.id)

        #expect(controller.slashMenuState == nil)
    }

    // MARK: - Navigation clavier, bouclage (sous-etape 6.4)

    @Test("moveSlashMenuSelection(.down) boucle sur la premiere commande apres la derniere")
    func moveDownLoopsToFirstAfterLast() {
        let fixture = makeNote(text: "")
        let block = fixture.block
        let controller = fixture.controller
        controller.updateSlashMenuState(for: block, plainText: "/", caretOffset: 1)
        let ids = SlashCommandFilter.match(query: "", in: SlashCommandRegistry.allCommands).map(\.command.id)

        for _ in 0..<(ids.count - 1) {
            controller.moveSlashMenuSelection(.down, in: block)
        }
        #expect(controller.slashMenuState?.selectedCommandID == ids.last)

        controller.moveSlashMenuSelection(.down, in: block)
        #expect(controller.slashMenuState?.selectedCommandID == ids.first)
    }

    @Test("moveSlashMenuSelection(.up) depuis la premiere commande boucle sur la derniere")
    func moveUpLoopsToLastFromFirst() {
        let fixture = makeNote(text: "")
        let block = fixture.block
        let controller = fixture.controller
        controller.updateSlashMenuState(for: block, plainText: "/", caretOffset: 1)
        let ids = SlashCommandFilter.match(query: "", in: SlashCommandRegistry.allCommands).map(\.command.id)
        #expect(controller.slashMenuState?.selectedCommandID == ids.first)

        controller.moveSlashMenuSelection(.up, in: block)

        #expect(controller.slashMenuState?.selectedCommandID == ids.last)
    }

    @Test("moveSlashMenuSelection retourne false si aucun menu n'est ouvert")
    func moveSelectionReturnsFalseWithoutMenu() {
        let fixture = makeNote(text: "")

        #expect(fixture.controller.moveSlashMenuSelection(.down, in: fixture.block) == false)
    }

    /// Garde de bloc de `moveSlashMenuSelection(_:in:)` : une fleche tapee dans un bloc
    /// AUTRE que celui qui porte le menu ouvert ne doit jamais piloter ce menu, et doit
    /// retomber sur la navigation de bloc a bloc (retour `false`). Aujourd'hui
    /// `noteBlockDidBeginEditing`/`noteBlockDidEndEditing` rendent la situation
    /// inatteignable en pratique, mais ce test verrouille la garde LOCALE a la methode :
    /// c'est elle qui doit tenir, pas la garantie etrangere qui la rend superflue
    /// aujourd'hui (voir la documentation de la methode).
    @Test("moveSlashMenuSelection ignore un menu ouvert sur un AUTRE bloc")
    func moveSelectionIgnoresMenuOpenedOnAnotherBlock() {
        let note = Note(title: "Test")
        let blockA = Block(order: 0, type: .paragraph, text: RichText(plainText: "/"), note: note)
        let blockB = Block(order: 1, type: .paragraph, text: RichText(plainText: ""), note: note)
        note.blocks = [blockA, blockB]
        let controller = EditorController(note: note)
        controller.updateSlashMenuState(for: blockA, plainText: "/", caretOffset: 1)
        let selectedBefore = controller.slashMenuState?.selectedCommandID

        #expect(controller.moveSlashMenuSelection(.down, in: blockB) == false)
        #expect(controller.slashMenuState?.selectedCommandID == selectedBefore)
    }

    // MARK: - Etat vide (aucun resultat NE ferme PAS le menu)

    @Test("Une requete sans aucun resultat garde le menu OUVERT, sans selection")
    func noMatchingQueryKeepsMenuOpenWithoutSelection() {
        let fixture = makeNote(text: "")
        let block = fixture.block
        let controller = fixture.controller
        controller.updateSlashMenuState(for: block, plainText: "/", caretOffset: 1)

        controller.updateSlashMenuState(for: block, plainText: "/zzzzzz", caretOffset: 7)

        #expect(controller.slashMenuState != nil)
        #expect(controller.slashMenuState?.selectedCommandID == nil)
    }

    @Test("Entree sur un etat vide est consommee sans effet (ne scinde pas le bloc)")
    func returnOnEmptyStateIsConsumedWithoutEffect() {
        let fixture = makeNote(text: "")
        let note = fixture.note
        let block = fixture.block
        let controller = fixture.controller
        controller.updateSlashMenuState(for: block, plainText: "/", caretOffset: 1)
        controller.updateSlashMenuState(for: block, plainText: "/zzzzzz", caretOffset: 7)

        let handled = controller.handleSlashMenuReturn(in: block)

        #expect(handled == true)
        #expect(BlockOrdering.topLevelBlocks(of: note).count == 1)
        #expect(controller.slashMenuState != nil) // toujours ouvert, l'utilisateur peut corriger
    }

    // MARK: - Helpers

    /// Groupe les trois valeurs dont chaque test a besoin -- une `struct` plutot qu'un
    /// tuple a trois membres (SwiftLint `large_tuple`). Dupliquee a l'identique dans
    /// `EditorControllerSlashMenuExecutionTests` : chaque fichier de test reste
    /// independant, meme motif que `SlashCommandFilterTests.command(...)`.
    private struct NoteFixture {
        let note: Note
        let block: Block
        let controller: EditorController
    }

    private func makeNote(text: String) -> NoteFixture {
        let note = Note(title: "Test")
        let block = Block(order: 0, type: .paragraph, text: RichText(plainText: text), note: note)
        note.blocks = [block]
        let controller = EditorController(note: note)
        return NoteFixture(note: note, block: block, controller: controller)
    }
}
