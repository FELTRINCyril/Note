import Foundation
import SlateModel
import SlateUI
import Testing

@testable import SlateEditor

/// `EditorController` : selection multi-blocs (sous-etape 5.6 -- extension clic + Maj,
/// glisser, Maj + fleche ; operations en lot supprimer/deplacer/convertir). Separe de
/// `EditorControllerTests` (5.3 a 5.5) pour rester sous la limite de longueur de
/// fichier de `CLAUDE.md` §5 -- meme suite logique, aucune duplication de setup.
@MainActor
@Suite("EditorController.Selection")
struct EditorControllerSelectionTests {
    @Test("selectBlock(_:) fonctionne sur un type non editable (generalisation, point 3)")
    func selectBlockWorksOnNonEditableType() {
        let note = Note(title: "Test")
        let divider = Block(order: 0, type: .divider, note: note)
        note.blocks = [divider]
        let controller = EditorController(note: note)

        controller.selectBlock(divider)

        #expect(controller.selectedBlockID == divider.id)
        #expect(controller.focusedBlockID == nil)
    }

    @Test("extendSelection(to:) etend depuis le bloc focalise, puis re-etend en conservant l'ancre")
    func extendSelectionExtendsFromFocusedBlockAndPreservesAnchor() {
        let note = Note(title: "Test")
        let first = Block(order: 0, type: .paragraph, text: RichText(plainText: "Un"), note: note)
        let second = Block(order: 1, type: .paragraph, text: RichText(plainText: "Deux"), note: note)
        let third = Block(order: 2, type: .paragraph, text: RichText(plainText: "Trois"), note: note)
        note.blocks = [first, second, third]
        let controller = EditorController(note: note)
        controller.noteBlockDidBeginEditing(first.id)

        controller.extendSelection(to: third)

        #expect(controller.blockSelectionRange == BlockSelectionRange(anchorBlockID: first.id, focusBlockID: third.id))
        #expect(controller.focusedBlockID == nil)
        #expect(controller.selectedBlockID == nil) // plage de plusieurs blocs : pas de "bloc seul"

        controller.extendSelection(to: second)

        #expect(controller.blockSelectionRange == BlockSelectionRange(anchorBlockID: first.id, focusBlockID: second.id))
    }

    @Test("extendSelectionVertically deplace la tete pas a pas, retourne false au bord du document")
    func extendSelectionVerticallyMovesFocusStepByStep() {
        let note = Note(title: "Test")
        let first = Block(order: 0, type: .paragraph, text: RichText(plainText: "Un"), note: note)
        let second = Block(order: 1, type: .paragraph, text: RichText(plainText: "Deux"), note: note)
        note.blocks = [first, second]
        let controller = EditorController(note: note)
        controller.noteBlockDidBeginEditing(first.id)

        let extended = controller.extendSelectionVertically(.down, from: first)

        #expect(extended == true)
        #expect(controller.blockSelectionRange == BlockSelectionRange(anchorBlockID: first.id, focusBlockID: second.id))

        let pastBound = controller.extendSelectionVertically(.down, from: first)
        #expect(pastBound == false)
    }

    @Test("beginBlockRangeDrag/continueBlockRangeDrag n'activent la plage qu'apres franchissement de la frontiere")
    func blockRangeDragActivatesOnlyAfterCrossingBoundary() {
        let note = Note(title: "Test")
        let first = Block(order: 0, type: .paragraph, text: RichText(plainText: "Un"), note: note)
        let second = Block(order: 1, type: .paragraph, text: RichText(plainText: "Deux"), note: note)
        note.blocks = [first, second]
        let controller = EditorController(note: note)
        controller.updateBlockFrames([
            first.id: CGRect(x: 0, y: 0, width: 100, height: 50),
            second.id: CGRect(x: 0, y: 50, width: 100, height: 50)
        ])

        controller.beginBlockRangeDrag(at: first)
        controller.continueBlockRangeDrag(pointerLocation: CGPoint(x: 10, y: 10))
        // Glisser encore DANS le bloc de depart : aucune plage, comportement natif de
        // selection de texte doit rester intact (spec E4).
        #expect(controller.blockSelectionRange == nil)

        controller.continueBlockRangeDrag(pointerLocation: CGPoint(x: 10, y: 60))
        // Frontiere franchie : la plage s'active.
        #expect(controller.blockSelectionRange == BlockSelectionRange(anchorBlockID: first.id, focusBlockID: second.id))

        controller.endBlockRangeDrag()
        #expect(controller.blockSelectionRange == BlockSelectionRange(anchorBlockID: first.id, focusBlockID: second.id))
    }

    @Test("deleteSelectionRange supprime toute la plage et selectionne le voisin")
    func deleteSelectionRangeRemovesEntireRangeAndSelectsNeighbor() {
        let note = Note(title: "Test")
        let first = Block(order: 0, type: .paragraph, text: RichText(plainText: "Un"), note: note)
        let second = Block(order: 1, type: .paragraph, text: RichText(plainText: "Deux"), note: note)
        let third = Block(order: 2, type: .paragraph, text: RichText(plainText: "Trois"), note: note)
        note.blocks = [first, second, third]
        let controller = EditorController(note: note)
        controller.selectBlock(first)
        controller.extendSelection(to: second)

        controller.deleteSelectionRange()

        let remaining = BlockOrdering.topLevelBlocks(of: note)
        #expect(remaining.map { $0.text?.plainText } == ["Trois"])
        #expect(controller.selectedBlockID == third.id)
    }

    @Test("deleteSelectionRange sur TOUS les blocs de la note garde la note editable")
    func deleteSelectionRangeCoveringEntireNoteKeepsNoteEditable() {
        let note = Note(title: "Test")
        let first = Block(order: 0, type: .paragraph, text: RichText(plainText: "Un"), note: note)
        let second = Block(order: 1, type: .paragraph, text: RichText(plainText: "Deux"), note: note)
        note.blocks = [first, second]
        let controller = EditorController(note: note)
        controller.selectBlock(first)
        controller.extendSelection(to: second)

        controller.deleteSelectionRange()

        let remaining = BlockOrdering.topLevelBlocks(of: note)
        #expect(remaining.count == 1)
        #expect(remaining[0].type == .paragraph)
        #expect(controller.selectedBlockID == remaining[0].id)
    }

    @Test("moveSelectionRangeUp/Down deplacent la plage en lot et persistent")
    func moveSelectionRangeUpAndDownPersist() {
        let note = Note(title: "Test", modifiedAt: .distantPast)
        let first = Block(order: 0, type: .paragraph, text: RichText(plainText: "A"), note: note)
        let second = Block(order: 1, type: .paragraph, text: RichText(plainText: "B"), note: note)
        let third = Block(order: 2, type: .paragraph, text: RichText(plainText: "C"), note: note)
        note.blocks = [first, second, third]
        let controller = EditorController(note: note)
        controller.selectBlock(second)
        controller.extendSelection(to: third)

        #expect(controller.moveSelectionRangeUp() == true)

        let ordered = BlockOrdering.topLevelBlocks(of: note)
        #expect(ordered.map { $0.text?.plainText } == ["B", "C", "A"])
        #expect(note.modifiedAt != .distantPast)
    }

    @Test("convertSelectionRange convertit la plage et la garde selectionnee")
    func convertSelectionRangeConvertsAndKeepsSelection() {
        let note = Note(title: "Test")
        let first = Block(order: 0, type: .paragraph, text: RichText(plainText: "Un"), note: note)
        let second = Block(order: 1, type: .paragraph, text: RichText(plainText: "Deux"), note: note)
        note.blocks = [first, second]
        let controller = EditorController(note: note)
        controller.selectBlock(first)
        controller.extendSelection(to: second)

        controller.convertSelectionRange(to: .bulletedList)

        #expect(first.type == .bulletedList)
        #expect(second.type == .bulletedList)
        #expect(controller.blockSelectionRange == BlockSelectionRange(anchorBlockID: first.id, focusBlockID: second.id))
    }

    @Test("selectionRangePositions() associe .single/.first/.middle/.last correctement")
    func selectionRangePositionsAssignsCorrectly() {
        let note = Note(title: "Test")
        let first = Block(order: 0, type: .paragraph, text: RichText(plainText: "Un"), note: note)
        let second = Block(order: 1, type: .paragraph, text: RichText(plainText: "Deux"), note: note)
        let third = Block(order: 2, type: .paragraph, text: RichText(plainText: "Trois"), note: note)
        note.blocks = [first, second, third]
        let controller = EditorController(note: note)

        controller.selectBlock(second)
        #expect(controller.selectionRangePositions() == [second.id: .single])

        controller.extendSelection(to: third)
        let positions = controller.selectionRangePositions()
        #expect(positions[second.id] == .first)
        #expect(positions[third.id] == .last)
        #expect(positions.count == 2)
    }
}
