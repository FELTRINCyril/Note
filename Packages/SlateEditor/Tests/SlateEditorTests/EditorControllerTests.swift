import Foundation
import SlateModel
import Testing

@testable import SlateEditor

/// `EditorController` : la facade `@Observable` que la couche AppKit appelle (voir sa
/// documentation, "pourquoi cette logique est testable hors AppKit"). Ces tests
/// n'instancient NI `NSTextView` NI `ModelContext` : uniquement des `Note`/`Block` en
/// memoire et l'observation directe de `focusedBlockID`/`selectedBlockID`/
/// `pendingCaretRequest`, exactement comme la couche AppKit les consommerait.
@MainActor
@Suite("EditorController")
struct EditorControllerTests {
    @Test("handleEnter deplace le focus sur le nouveau bloc et programme son caret")
    func handleEnterMovesFocusAndSchedulesCaret() {
        let note = Note(title: "Test")
        let block = Block(order: 0, type: .paragraph, text: RichText(plainText: "Bonjour"), note: note)
        note.blocks = [block]
        let controller = EditorController(note: note)

        controller.handleEnter(in: block, caretOffset: 7)

        let blocks = BlockOrdering.topLevelBlocks(of: note)
        #expect(blocks.count == 2)
        #expect(controller.focusedBlockID == blocks[1].id)
        #expect(controller.consumePendingCaretRequest(for: blocks[1].id) != nil)
    }

    @Test("handleEnter met a jour Note.modifiedAt et recalcule plainText (point de sauvegarde unique)")
    func handleEnterPersistsThroughNote() {
        let note = Note(title: "Test", modifiedAt: .distantPast)
        let block = Block(order: 0, type: .paragraph, text: RichText(plainText: "Bonjour"), note: note)
        note.blocks = [block]
        let controller = EditorController(note: note)

        controller.handleEnter(in: block, caretOffset: 7)

        #expect(note.modifiedAt != .distantPast)
        #expect(note.plainText == "Bonjour")
    }

    @Test("consumePendingCaretRequest(for:) ne retourne la requete qu'une seule fois")
    func pendingCaretRequestIsConsumedOnce() {
        let note = Note(title: "Test")
        let block = Block(order: 0, type: .paragraph, text: RichText(plainText: "Bonjour"), note: note)
        note.blocks = [block]
        let controller = EditorController(note: note)
        controller.handleEnter(in: block, caretOffset: 7)
        let newBlockID = controller.focusedBlockID

        let first = newBlockID.flatMap { controller.consumePendingCaretRequest(for: $0) }
        let second = newBlockID.flatMap { controller.consumePendingCaretRequest(for: $0) }

        #expect(first != nil)
        #expect(second == nil)
    }

    @Test("consumePendingCaretRequest(for:) ignore une requete qui ne vise pas ce bloc")
    func pendingCaretRequestIgnoresWrongBlock() {
        let note = Note(title: "Test")
        let block = Block(order: 0, type: .paragraph, text: RichText(plainText: "Bonjour"), note: note)
        note.blocks = [block]
        let controller = EditorController(note: note)
        controller.handleEnter(in: block, caretOffset: 7)

        #expect(controller.consumePendingCaretRequest(for: UUID()) == nil)
    }

    @Test("handleBackspaceAtBlockStart retourne false et ne bouge pas le focus sur le premier bloc")
    func handleBackspaceOnFirstBlockReturnsFalse() {
        let note = Note(title: "Test")
        let block = Block(order: 0, type: .paragraph, text: RichText(plainText: "Seul"), note: note)
        note.blocks = [block]
        let controller = EditorController(note: note)

        let handled = controller.handleBackspaceAtBlockStart(block)

        #expect(handled == false)
        #expect(controller.focusedBlockID == nil)
        #expect(controller.pendingCaretRequest == nil)
    }

    @Test("handleMoveUp/handleMoveDown restent sur place aux bords du document (aucune sortie de limites)")
    func moveUpDownStayWithinBoundsAtDocumentEdges() {
        let note = Note(title: "Test")
        let first = Block(order: 0, type: .paragraph, text: RichText(plainText: "Un"), note: note)
        let second = Block(order: 1, type: .paragraph, text: RichText(plainText: "Deux"), note: note)
        note.blocks = [first, second]
        let controller = EditorController(note: note)

        let movedUpFromFirst = controller.handleMoveUp(from: first, visualColumnX: 10)
        let movedDownFromLast = controller.handleMoveDown(from: second, visualColumnX: 10)

        #expect(movedUpFromFirst == false)
        #expect(movedDownFromLast == false)
        #expect(controller.focusedBlockID == nil)
    }

    @Test("handleMoveDown deplace le focus vers le bloc suivant, avec une requete de colonne visuelle")
    func moveDownFocusesNextBlockWithVisualColumn() {
        let note = Note(title: "Test")
        let first = Block(order: 0, type: .paragraph, text: RichText(plainText: "Un"), note: note)
        let second = Block(order: 1, type: .paragraph, text: RichText(plainText: "Deux"), note: note)
        note.blocks = [first, second]
        let controller = EditorController(note: note)

        let moved = controller.handleMoveDown(from: first, visualColumnX: 42)

        #expect(moved == true)
        #expect(controller.focusedBlockID == second.id)
        #expect(
            controller.consumePendingCaretRequest(for: second.id)
                == EditorCaretRequest(blockID: second.id, placement: .visualColumn(x: 42, edge: .top))
        )
    }

    @Test("handleMoveUp deplace le focus vers le bloc precedent, avec atterrissage sur le bord BAS")
    func moveUpFocusesPreviousBlockLandingOnBottomEdge() {
        let note = Note(title: "Test")
        let first = Block(order: 0, type: .paragraph, text: RichText(plainText: "Un"), note: note)
        let second = Block(order: 1, type: .paragraph, text: RichText(plainText: "Deux"), note: note)
        note.blocks = [first, second]
        let controller = EditorController(note: note)

        let moved = controller.handleMoveUp(from: second, visualColumnX: 24)

        #expect(moved == true)
        #expect(controller.focusedBlockID == first.id)
        #expect(
            controller.consumePendingCaretRequest(for: first.id)
                == EditorCaretRequest(blockID: first.id, placement: .visualColumn(x: 24, edge: .bottom))
        )
    }

    @Test("handleEscape sort de l'edition et selectionne le bloc entier")
    func handleEscapeSelectsWholeBlock() {
        let note = Note(title: "Test")
        let block = Block(order: 0, type: .paragraph, text: RichText(plainText: "Bonjour"), note: note)
        note.blocks = [block]
        let controller = EditorController(note: note)
        controller.noteBlockDidBeginEditing(block.id)

        controller.handleEscape(in: block)

        #expect(controller.focusedBlockID == nil)
        #expect(controller.selectedBlockID == block.id)
    }

    @Test("handleEnterOnSelectedBlock rentre en edition, caret en fin de contenu")
    func handleEnterOnSelectedBlockEntersEditingAtEnd() {
        let note = Note(title: "Test")
        let block = Block(order: 0, type: .paragraph, text: RichText(plainText: "Bonjour"), note: note)
        note.blocks = [block]
        let controller = EditorController(note: note)
        controller.handleEscape(in: block)

        controller.handleEnterOnSelectedBlock()

        #expect(controller.selectedBlockID == nil)
        #expect(controller.focusedBlockID == block.id)
        #expect(controller.consumePendingCaretRequest(for: block.id) == EditorCaretRequest(blockID: block.id, placement: .end))
    }

    @Test("appendTrailingParagraph ajoute un paragraphe vide en fin de note et lui donne le focus")
    func appendTrailingParagraphAddsBlockAtEnd() {
        let note = Note(title: "Test")
        let block = Block(order: 0, type: .paragraph, text: RichText(plainText: "Bonjour"), note: note)
        note.blocks = [block]
        let controller = EditorController(note: note)

        controller.appendTrailingParagraph()

        let blocks = BlockOrdering.topLevelBlocks(of: note)
        #expect(blocks.count == 2)
        #expect(blocks[1].text?.isEmpty == true)
        #expect(controller.focusedBlockID == blocks[1].id)
    }

    @Test("appendTrailingParagraph fonctionne sur une note sans aucun bloc")
    func appendTrailingParagraphOnEmptyNote() {
        let note = Note(title: "Test")
        let controller = EditorController(note: note)

        controller.appendTrailingParagraph()

        let blocks = BlockOrdering.topLevelBlocks(of: note)
        #expect(blocks.count == 1)
        #expect(controller.focusedBlockID == blocks.first?.id)
    }

    // MARK: - Menu de bloc (sous-etape 5.4)

    @Test("insertBlockBelow insere un paragraphe vide juste apres le bloc et lui donne le focus")
    func insertBlockBelowInsertsAndFocuses() {
        let note = Note(title: "Test")
        let block = Block(order: 0, type: .paragraph, text: RichText(plainText: "Un"), note: note)
        note.blocks = [block]
        let controller = EditorController(note: note)

        controller.insertBlockBelow(block)

        let blocks = BlockOrdering.topLevelBlocks(of: note)
        #expect(blocks.count == 2)
        #expect(blocks[1].text?.isEmpty == true)
        #expect(controller.focusedBlockID == blocks[1].id)
        #expect(controller.consumePendingCaretRequest(for: blocks[1].id) != nil)
    }

    @Test("duplicateBlock selectionne le double (pas de focus d'edition)")
    func duplicateBlockSelectsCopy() {
        let note = Note(title: "Test")
        let block = Block(order: 0, type: .paragraph, text: RichText(plainText: "Un"), note: note)
        note.blocks = [block]
        let controller = EditorController(note: note)

        controller.duplicateBlock(block)

        let blocks = BlockOrdering.topLevelBlocks(of: note)
        #expect(blocks.count == 2)
        #expect(controller.focusedBlockID == nil)
        #expect(controller.selectedBlockID == blocks[1].id)
    }

    @Test("deleteBlock selectionne le voisin suivant apres suppression")
    func deleteBlockSelectsNextNeighbor() {
        let note = Note(title: "Test")
        let first = Block(order: 0, type: .paragraph, text: RichText(plainText: "Un"), note: note)
        let second = Block(order: 1, type: .paragraph, text: RichText(plainText: "Deux"), note: note)
        note.blocks = [first, second]
        let controller = EditorController(note: note)

        controller.deleteBlock(first)

        #expect(BlockOrdering.topLevelBlocks(of: note).map(\.id) == [second.id])
        #expect(controller.selectedBlockID == second.id)
    }

    @Test("deleteBlock sur le dernier bloc de la note garde la note editable et selectionne le paragraphe de secours")
    func deleteBlockOnLastBlockKeepsNoteEditable() {
        let note = Note(title: "Test")
        let only = Block(order: 0, type: .paragraph, text: RichText(plainText: "Seul"), note: note)
        note.blocks = [only]
        let controller = EditorController(note: note)

        controller.deleteBlock(only)

        let blocks = BlockOrdering.topLevelBlocks(of: note)
        #expect(blocks.count == 1)
        #expect(blocks[0].id != only.id)
        #expect(controller.selectedBlockID == blocks[0].id)
    }

    // MARK: - Conversion de type (sous-etape 5.5)

    @Test("convertBlock delegue a BlockConversion, selectionne le bloc converti et persiste")
    func convertBlockDelegatesSelectsAndPersists() {
        let note = Note(title: "Test", modifiedAt: .distantPast)
        let block = Block(order: 0, type: .paragraph, text: RichText(plainText: "Bonjour"), note: note)
        note.blocks = [block]
        let controller = EditorController(note: note)

        controller.convertBlock(block, to: .heading1)

        #expect(block.type == .heading1)
        #expect(block.text?.plainText == "Bonjour")
        #expect(controller.focusedBlockID == nil)
        #expect(controller.selectedBlockID == block.id)
    }

    @Test("convertBlock met a jour Note.modifiedAt et recalcule le texte derive")
    func convertBlockPersistsThroughNote() {
        let note = Note(title: "Test", modifiedAt: .distantPast)
        let paragraph = Block(order: 0, type: .paragraph, text: RichText(plainText: "Bonjour"), note: note)
        let divider = Block(order: 1, type: .divider, note: note)
        note.blocks = [paragraph, divider]
        note.refreshDerivedText()
        #expect(note.plainText == "Bonjour")
        let controller = EditorController(note: note)

        // Conversion vers un type non porteur de texte derive (`divider` n'est pas
        // convertible -- ici on verifie le recalcul via une conversion NEUTRE en texte
        // mais qui doit tout de meme repasser par le point de sauvegarde unique).
        controller.convertBlock(paragraph, to: .quote)

        #expect(note.modifiedAt != .distantPast)
        #expect(note.plainText == "Bonjour") // meme texte, la citation reste porteuse de texte derive
    }

    @Test("moveBlockUp/moveBlockDown recalculent order et retournent false aux bords")
    func moveBlockUpDownAtBoundaries() {
        let note = Note(title: "Test")
        let first = Block(order: 0, type: .paragraph, text: RichText(plainText: "Un"), note: note)
        let second = Block(order: 1, type: .paragraph, text: RichText(plainText: "Deux"), note: note)
        note.blocks = [first, second]
        let controller = EditorController(note: note)

        #expect(controller.moveBlockUp(first) == false)
        #expect(controller.moveBlockDown(second) == false)

        #expect(controller.moveBlockDown(first) == true)
        let blocks = BlockOrdering.topLevelBlocks(of: note)
        #expect(blocks.map { $0.text?.plainText } == ["Deux", "Un"])
        #expect(blocks.map(\.order) == [0, 1])
    }
}
