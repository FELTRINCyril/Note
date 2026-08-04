import Foundation
import SlateModel
import SlateUI
import Testing

@testable import SlateEditor

/// `BlockSelectionOperations`/`BlockSelectionRange` : resolution d'une plage contre le
/// DFS aplati (`BlockOrdering.flattenedBlocks`), extension pas a pas, suppression,
/// deplacement et conversion en lot (sous-etape 5.6). Aucun `NSTextView`/`ModelContext` :
/// uniquement des `Note`/`Block` en memoire, comme les suites des sous-etapes precedentes.
@MainActor
@Suite("BlockSelectionOperations")
struct BlockSelectionOperationsTests {
    // MARK: - Resolution de la plage (ordre DFS aplati, blocs imbriques)

    @Test("orderedBlocks(of:in:) respecte l'ordre DFS aplati a travers une liste imbriquee")
    func orderedBlocksRespectsFlattenedOrderAcrossNesting() {
        let note = Note(title: "Test")
        let first = Block(order: 0, type: .paragraph, text: RichText(plainText: "Un"), note: note)
        let list = Block(order: 1, type: .bulletedList, text: RichText(plainText: "Liste"), note: note)
        let nested = Block(
            order: 0, type: .bulletedList, text: RichText(plainText: "Imbrique"), note: note, parent: list
        )
        list.children = [nested]
        let last = Block(order: 2, type: .paragraph, text: RichText(plainText: "Trois"), note: note)
        note.blocks = [first, list, nested, last]

        // La plage englobe [first ... last] dans l'ordre d'affichage : elle DOIT
        // inclure `nested` (visuellement entre `list` et `last`), meme si `note.blocks`
        // (ordre non specifie) le place ailleurs.
        let range = BlockSelectionRange(anchorBlockID: first.id, focusBlockID: last.id)
        let ordered = BlockSelectionOperations.orderedBlocks(of: range, in: note)

        #expect(ordered.map(\.id) == [first.id, list.id, nested.id, last.id])
    }

    @Test("orderedBlocks(of:in:) fonctionne quel que soit l'ordre ancre/tete")
    func orderedBlocksWorksRegardlessOfAnchorFocusOrder() {
        let note = Note(title: "Test")
        let first = Block(order: 0, type: .paragraph, text: RichText(plainText: "Un"), note: note)
        let second = Block(order: 1, type: .paragraph, text: RichText(plainText: "Deux"), note: note)
        let third = Block(order: 2, type: .paragraph, text: RichText(plainText: "Trois"), note: note)
        note.blocks = [first, second, third]

        let forward = BlockSelectionOperations.orderedBlocks(
            of: BlockSelectionRange(anchorBlockID: first.id, focusBlockID: third.id), in: note
        )
        let backward = BlockSelectionOperations.orderedBlocks(
            of: BlockSelectionRange(anchorBlockID: third.id, focusBlockID: first.id), in: note
        )

        #expect(forward.map(\.id) == [first.id, second.id, third.id])
        #expect(backward.map(\.id) == [first.id, second.id, third.id])
    }

    @Test("orderedBlocks(of:in:) est vide si l'un des deux blocs n'appartient plus a la note")
    func orderedBlocksIsEmptyForStaleBlockID() {
        let note = Note(title: "Test")
        let only = Block(order: 0, type: .paragraph, text: RichText(plainText: "Seul"), note: note)
        note.blocks = [only]

        let range = BlockSelectionRange(anchorBlockID: only.id, focusBlockID: UUID())

        #expect(BlockSelectionOperations.orderedBlocks(of: range, in: note).isEmpty)
    }

    // MARK: - `SlateBlockRangePosition` (spec E4 : coins arrondis seulement aux extremites)

    @Test("rangePositions(forOrderedIDs:) attribue .single a un bloc seul")
    func rangePositionsAssignsSingleForOneBlock() {
        let id = UUID()

        let positions = BlockSelectionOperations.rangePositions(forOrderedIDs: [id])

        #expect(positions == [id: .single])
    }

    @Test("rangePositions(forOrderedIDs:) attribue first/middle/last a une plage de trois")
    func rangePositionsAssignsFirstMiddleLastForThreeBlocks() {
        let ids = [UUID(), UUID(), UUID()]

        let positions = BlockSelectionOperations.rangePositions(forOrderedIDs: ids)

        #expect(positions[ids[0]] == .first)
        #expect(positions[ids[1]] == .middle)
        #expect(positions[ids[2]] == .last)
    }

    @Test("rangePositions(forOrderedIDs:) attribue first/last (aucun middle) a une plage de deux")
    func rangePositionsAssignsFirstLastForTwoBlocks() {
        let ids = [UUID(), UUID()]

        let positions = BlockSelectionOperations.rangePositions(forOrderedIDs: ids)

        #expect(positions[ids[0]] == .first)
        #expect(positions[ids[1]] == .last)
    }

    // MARK: - Extension pas a pas (Maj+fleche)

    @Test("extendingByStep(...) etend dans les deux sens en conservant l'ancre")
    func extendingByStepExtendsBothDirectionsPreservingAnchor() {
        let note = Note(title: "Test")
        let first = Block(order: 0, type: .paragraph, text: RichText(plainText: "Un"), note: note)
        let second = Block(order: 1, type: .paragraph, text: RichText(plainText: "Deux"), note: note)
        let third = Block(order: 2, type: .paragraph, text: RichText(plainText: "Trois"), note: note)
        note.blocks = [first, second, third]

        let firstStep = BlockSelectionOperations.extendingByStep(
            from: nil, fallbackBlockID: second.id, direction: .down, in: note
        )
        #expect(firstStep == BlockSelectionRange(anchorBlockID: second.id, focusBlockID: third.id))

        let secondStep = BlockSelectionOperations.extendingByStep(
            from: firstStep, fallbackBlockID: second.id, direction: .up, in: note
        )
        // L'ancre (second) ne bouge jamais ; la tete revient sur l'ancre elle-meme.
        #expect(secondStep == BlockSelectionRange(anchorBlockID: second.id, focusBlockID: second.id))
    }

    @Test("extendingByStep(...) retourne nil au bord du document (aucune sortie de limites)")
    func extendingByStepReturnsNilAtDocumentBounds() {
        let note = Note(title: "Test")
        let first = Block(order: 0, type: .paragraph, text: RichText(plainText: "Un"), note: note)
        let second = Block(order: 1, type: .paragraph, text: RichText(plainText: "Deux"), note: note)
        note.blocks = [first, second]

        let pastTop = BlockSelectionOperations.extendingByStep(
            from: nil, fallbackBlockID: first.id, direction: .up, in: note
        )
        let pastBottom = BlockSelectionOperations.extendingByStep(
            from: nil, fallbackBlockID: second.id, direction: .down, in: note
        )

        #expect(pastTop == nil)
        #expect(pastBottom == nil)
    }

    // MARK: - Suppression en lot

    @Test("deleteRange(_:in:) supprime tous les blocs de la plage et renumerote les survivants")
    func deleteRangeRemovesAllBlocksInRange() {
        let note = Note(title: "Test")
        let first = Block(order: 0, type: .paragraph, text: RichText(plainText: "Un"), note: note)
        let second = Block(order: 1, type: .paragraph, text: RichText(plainText: "Deux"), note: note)
        let third = Block(order: 2, type: .paragraph, text: RichText(plainText: "Trois"), note: note)
        let fourth = Block(order: 3, type: .paragraph, text: RichText(plainText: "Quatre"), note: note)
        note.blocks = [first, second, third, fourth]

        BlockSelectionOperations.deleteRange(
            BlockSelectionRange(anchorBlockID: second.id, focusBlockID: third.id), in: note
        )

        let remaining = BlockOrdering.topLevelBlocks(of: note)
        #expect(remaining.map { $0.text?.plainText } == ["Un", "Quatre"])
        #expect(remaining.map(\.order) == [0, 1])
    }

    @Test("deleteRange(_:in:) promeut les enfants NON selectionnes d'un parent supprime")
    func deleteRangePromotesUnselectedChildren() {
        let note = Note(title: "Test")
        let list = Block(order: 0, type: .bulletedList, text: RichText(plainText: "Liste"), note: note)
        let child = Block(order: 0, type: .bulletedList, text: RichText(plainText: "Enfant"), note: note, parent: list)
        list.children = [child]
        let after = Block(order: 1, type: .paragraph, text: RichText(plainText: "Apres"), note: note)
        note.blocks = [list, child, after]

        // Seul `list` est selectionne (une plage d'UN bloc) : `child` n'est PAS dans la
        // plage, `after` non plus.
        BlockSelectionOperations.deleteRange(BlockSelectionRange(single: list.id), in: note)

        let remaining = BlockOrdering.topLevelBlocks(of: note)
        #expect(remaining.map(\.id) == [child.id, after.id])
        #expect(child.parent == nil)
    }

    @Test("deleteRange(_:in:) sur TOUS les blocs de la note laisse un paragraphe de secours")
    func deleteRangeCoveringEntireNoteKeepsNoteEditable() {
        let note = Note(title: "Test")
        let first = Block(order: 0, type: .paragraph, text: RichText(plainText: "Un"), note: note)
        let second = Block(order: 1, type: .divider, note: note)
        let third = Block(order: 2, type: .paragraph, text: RichText(plainText: "Trois"), note: note)
        note.blocks = [first, second, third]

        BlockSelectionOperations.deleteRange(
            BlockSelectionRange(anchorBlockID: first.id, focusBlockID: third.id), in: note
        )

        let remaining = BlockOrdering.topLevelBlocks(of: note)
        #expect(remaining.count == 1)
        #expect(remaining[0].type == .paragraph)
        #expect(remaining[0].text?.isEmpty == true)
    }
}
