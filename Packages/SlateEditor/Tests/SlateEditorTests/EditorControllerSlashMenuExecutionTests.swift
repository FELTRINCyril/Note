import Foundation
import SlateModel
import Testing

@testable import SlateEditor

/// Execution des commandes "/" (docs/06_slash_commandes.md, sous-etape 6.6) : retrait
/// de `/` + la requete, conversion en place vs insertion d'un nouveau bloc, cas
/// particulier `divider`, preservation du formatage inline, clic et survol souris.
/// Extrait de `EditorControllerSlashMenuTests` (ouverture/fermeture/navigation) pour
/// rester sous la limite de longueur de `CLAUDE.md` §5 -- meme motif exact que
/// `EditorControllerTests`/`EditorControllerSelectionTests`.
@MainActor
@Suite("EditorController.SlashMenu.Execution")
struct EditorControllerSlashMenuExecutionTests {
    // MARK: - Conversion en place (bloc vide apres retrait)

    @Test("Execution : bloc vide apres retrait -> conversion en place, caret dans le meme bloc")
    func executionOnEmptyLeftoverConvertsInPlace() {
        let fixture = makeNote(text: "/code")
        let note = fixture.note
        let block = fixture.block
        let controller = fixture.controller
        controller.updateSlashMenuState(for: block, plainText: "/", caretOffset: 1)
        controller.updateSlashMenuState(for: block, plainText: "/code", caretOffset: 5)
        #expect(controller.slashMenuState?.selectedCommandID == "code")

        let handled = controller.handleSlashMenuReturn(in: block)

        #expect(handled == true)
        #expect(controller.slashMenuState == nil)
        #expect(block.type == .code)
        #expect(block.text?.isEmpty == true)
        #expect(BlockOrdering.topLevelBlocks(of: note).count == 1)
        #expect(controller.focusedBlockID == block.id)
        let expectedRequest = EditorCaretRequest(blockID: block.id, placement: .offset(0))
        #expect(controller.consumePendingCaretRequest(for: block.id) == expectedRequest)
    }

    // MARK: - Insertion en dessous (bloc non vide apres retrait)

    @Test("Execution : bloc non vide apres retrait -> nouveau bloc insere en dessous, focalise")
    func executionOnNonEmptyLeftoverInsertsBelow() {
        let fixture = makeNote(text: "Notes /todo")
        let note = fixture.note
        let block = fixture.block
        let controller = fixture.controller
        controller.updateSlashMenuState(for: block, plainText: "Notes /", caretOffset: 7)
        controller.updateSlashMenuState(for: block, plainText: "Notes /todo", caretOffset: 11)
        #expect(controller.slashMenuState?.selectedCommandID == "todo")

        controller.handleSlashMenuReturn(in: block)

        let blocks = BlockOrdering.topLevelBlocks(of: note)
        #expect(blocks.count == 2)
        #expect(blocks[0].id == block.id)
        #expect(blocks[0].text?.plainText == "Notes ")
        #expect(blocks[0].type == .paragraph) // le bloc D'ORIGINE garde son type inchange
        #expect(blocks[1].type == .todo)
        #expect(blocks[1].text?.isEmpty == true)
        #expect(controller.focusedBlockID == blocks[1].id)
    }

    // MARK: - Cas particulier divider

    @Test("Divider, retrait vide : le separateur prend la place du bloc, un paragraphe vide focalise le suit")
    func dividerOnEmptyLeftoverConvertsInPlaceAndAppendsParagraph() {
        let fixture = makeNote(text: "/divider")
        let note = fixture.note
        let block = fixture.block
        let controller = fixture.controller
        controller.updateSlashMenuState(for: block, plainText: "/", caretOffset: 1)
        controller.updateSlashMenuState(for: block, plainText: "/divider", caretOffset: 8)
        #expect(controller.slashMenuState?.selectedCommandID == "divider")

        controller.handleSlashMenuReturn(in: block)

        let blocks = BlockOrdering.topLevelBlocks(of: note)
        #expect(blocks.count == 2)
        #expect(blocks[0].id == block.id)
        #expect(blocks[0].type == .divider)
        #expect(blocks[1].type == .paragraph)
        #expect(blocks[1].text?.isEmpty == true)
        #expect(controller.focusedBlockID == blocks[1].id) // JAMAIS le separateur (pas de caret possible)
    }

    @Test("Divider, retrait non vide : nouveau bloc separateur en dessous, puis paragraphe vide focalise")
    func dividerOnNonEmptyLeftoverInsertsBelowAndAppendsParagraph() {
        let fixture = makeNote(text: "Notes /divider")
        let note = fixture.note
        let block = fixture.block
        let controller = fixture.controller
        controller.updateSlashMenuState(for: block, plainText: "Notes /", caretOffset: 7)
        controller.updateSlashMenuState(for: block, plainText: "Notes /divider", caretOffset: 14)

        controller.handleSlashMenuReturn(in: block)

        let blocks = BlockOrdering.topLevelBlocks(of: note)
        #expect(blocks.count == 3)
        #expect(blocks[0].id == block.id)
        #expect(blocks[0].text?.plainText == "Notes ")
        #expect(blocks[0].type == .paragraph)
        #expect(blocks[1].type == .divider)
        #expect(blocks[2].type == .paragraph)
        #expect(blocks[2].text?.isEmpty == true)
        #expect(controller.focusedBlockID == blocks[2].id)
    }

    // MARK: - Preservation du RichText porteur d'attributs inline (le test le plus important)

    @Test("L'execution d'une commande / preserve le formatage inline du texte QUI RESTE dans le bloc d'origine")
    func executionPreservesInlineAttributesOfLeftoverText() {
        // "Hello /code" avec "Hello" en gras -- le retrait de " /code" ne doit RIEN
        // toucher au gras porte par "Hello", jamais en repassant par une reconstruction
        // depuis `String`/`plainText` (voir la doc de tete de `EditorController+
        // SlashMenu.swift` et de `RichText.removingCharacters(in:)`).
        var richText = RichText(plainText: "Hello /code")
        richText.apply(.bold, to: richText.range(charactersOffset: 0..<5))
        let note = Note(title: "Test")
        let block = Block(order: 0, type: .paragraph, text: richText, note: note)
        note.blocks = [block]
        let controller = EditorController(note: note)

        controller.updateSlashMenuState(for: block, plainText: "Hello /", caretOffset: 7)
        controller.updateSlashMenuState(for: block, plainText: "Hello /code", caretOffset: 11)
        controller.handleSlashMenuReturn(in: block)

        let leftover = block.text
        #expect(leftover?.plainText == "Hello ")
        let boldRange = leftover?.range(charactersOffset: 0..<5)
        #expect(boldRange != nil)
        if let boldRange {
            #expect(leftover?.attributedString[boldRange].inlinePresentationIntent == .stronglyEmphasized)
        }
    }

    // MARK: - Clic souris et survol

    @Test("confirmSlashMenuCommand execute TOUJOURS la commande CLIQUEE, meme differente de la selection clavier")
    func clickExecutesClickedCommandRegardlessOfKeyboardSelection() {
        let fixture = makeNote(text: "/co")
        let note = fixture.note
        let block = fixture.block
        let controller = fixture.controller
        controller.updateSlashMenuState(for: block, plainText: "/", caretOffset: 1)
        controller.updateSlashMenuState(for: block, plainText: "/co", caretOffset: 3)
        // Deplace la selection clavier ailleurs que "code" avant le clic.
        controller.moveSlashMenuSelection(.down, in: block)

        controller.confirmSlashMenuCommand("code", in: block)

        #expect(block.type == .code)
        #expect(BlockOrdering.topLevelBlocks(of: note).count == 1)
    }

    @Test("hoverSlashMenuItem deplace la selection SANS executer la commande")
    func hoverMovesSelectionWithoutExecuting() {
        let fixture = makeNote(text: "/")
        let note = fixture.note
        let block = fixture.block
        let controller = fixture.controller
        controller.updateSlashMenuState(for: block, plainText: "/", caretOffset: 1)

        controller.hoverSlashMenuItem("code")

        #expect(controller.slashMenuState?.selectedCommandID == "code")
        #expect(block.type == .paragraph) // aucune execution
        #expect(BlockOrdering.topLevelBlocks(of: note).count == 1)
    }

    // MARK: - Helpers (dupliques depuis `EditorControllerSlashMenuTests`, voir la doc
    // de tete de fichier : chaque fichier de test reste independant)

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
