import Foundation
import SlateModel
import Testing

@testable import SlateEditor

/// `BlockSelectionOperations` : deplacement en lot (freres contigus de meme niveau) et
/// conversion en lot. Separe de `BlockSelectionOperationsTests` (resolution de la
/// plage, extension, suppression) pour rester sous la limite de longueur de type de
/// `CLAUDE.md` §5 -- meme suite logique, aucune duplication de setup.
@MainActor
@Suite("BlockSelectionOperations.MoveConvert")
struct BlockSelectionOperationsMoveConvertTests {
    // MARK: - Deplacement en lot (freres contigus de meme niveau)

    @Test("moveRangeUp(_:in:) deplace le groupe entier d'un cran, sans perdre la contigute")
    func moveRangeUpMovesGroupAsOneUnit() {
        let note = Note(title: "Test")
        let first = Block(order: 0, type: .paragraph, text: RichText(plainText: "A"), note: note)
        let second = Block(order: 1, type: .paragraph, text: RichText(plainText: "B"), note: note)
        let third = Block(order: 2, type: .paragraph, text: RichText(plainText: "C"), note: note)
        let fourth = Block(order: 3, type: .paragraph, text: RichText(plainText: "D"), note: note)
        let fifth = Block(order: 4, type: .paragraph, text: RichText(plainText: "E"), note: note)
        note.blocks = [first, second, third, fourth, fifth]

        let moved = BlockSelectionOperations.moveRangeUp(
            BlockSelectionRange(anchorBlockID: second.id, focusBlockID: third.id), in: note
        )

        #expect(moved == true)
        let ordered = BlockOrdering.topLevelBlocks(of: note)
        #expect(ordered.map { $0.text?.plainText } == ["B", "C", "A", "D", "E"])
        #expect(ordered.map(\.order) == [0, 1, 2, 3, 4])
    }

    @Test("moveRangeDown(_:in:) deplace le groupe entier d'un cran")
    func moveRangeDownMovesGroupAsOneUnit() {
        let note = Note(title: "Test")
        let first = Block(order: 0, type: .paragraph, text: RichText(plainText: "A"), note: note)
        let second = Block(order: 1, type: .paragraph, text: RichText(plainText: "B"), note: note)
        let third = Block(order: 2, type: .paragraph, text: RichText(plainText: "C"), note: note)
        let fourth = Block(order: 3, type: .paragraph, text: RichText(plainText: "D"), note: note)
        note.blocks = [first, second, third, fourth]

        let moved = BlockSelectionOperations.moveRangeDown(
            BlockSelectionRange(anchorBlockID: first.id, focusBlockID: second.id), in: note
        )

        #expect(moved == true)
        let ordered = BlockOrdering.topLevelBlocks(of: note)
        #expect(ordered.map { $0.text?.plainText } == ["C", "A", "B", "D"])
    }

    @Test("moveRangeUp(_:in:) sur le premier segment de la fratrie ne fait rien (aucune sortie de limites)")
    func moveRangeUpAtTopBoundaryDoesNothing() {
        let note = Note(title: "Test")
        let first = Block(order: 0, type: .paragraph, text: RichText(plainText: "A"), note: note)
        let second = Block(order: 1, type: .paragraph, text: RichText(plainText: "B"), note: note)
        let third = Block(order: 2, type: .paragraph, text: RichText(plainText: "C"), note: note)
        note.blocks = [first, second, third]

        let moved = BlockSelectionOperations.moveRangeUp(
            BlockSelectionRange(anchorBlockID: first.id, focusBlockID: second.id), in: note
        )

        #expect(moved == false)
        #expect(BlockOrdering.topLevelBlocks(of: note).map { $0.text?.plainText } == ["A", "B", "C"])
    }

    @Test("moveRangeDown(_:in:) sur le dernier segment de la fratrie ne fait rien (aucune sortie de limites)")
    func moveRangeDownAtBottomBoundaryDoesNothing() {
        let note = Note(title: "Test")
        let first = Block(order: 0, type: .paragraph, text: RichText(plainText: "A"), note: note)
        let second = Block(order: 1, type: .paragraph, text: RichText(plainText: "B"), note: note)
        let third = Block(order: 2, type: .paragraph, text: RichText(plainText: "C"), note: note)
        note.blocks = [first, second, third]

        let moved = BlockSelectionOperations.moveRangeDown(
            BlockSelectionRange(anchorBlockID: second.id, focusBlockID: third.id), in: note
        )

        #expect(moved == false)
        #expect(BlockOrdering.topLevelBlocks(of: note).map { $0.text?.plainText } == ["A", "B", "C"])
    }

    @Test("moveRangeUp(_:in:) refuse une plage qui traverse des niveaux d'imbrication differents")
    func moveRangeRefusesRangeAcrossNestingLevels() {
        let note = Note(title: "Test")
        let list = Block(order: 0, type: .bulletedList, text: RichText(plainText: "Liste"), note: note)
        let child = Block(order: 0, type: .bulletedList, text: RichText(plainText: "Enfant"), note: note, parent: list)
        list.children = [child]
        let after = Block(order: 1, type: .paragraph, text: RichText(plainText: "Apres"), note: note)
        note.blocks = [list, child, after]

        // La plage [list ... after] inclut `child` (visuellement entre les deux), qui
        // n'a PAS le meme parent que `list`/`after` (racine) : deplacement refuse.
        let moved = BlockSelectionOperations.moveRangeDown(
            BlockSelectionRange(anchorBlockID: list.id, focusBlockID: after.id), in: note
        )

        #expect(moved == false)
    }

    @Test("canMoveRange(_:in:by:) reflete exactement moveRangeUp/moveRangeDown, sans muter")
    func canMoveRangeMatchesActualMoveWithoutMutating() {
        let note = Note(title: "Test")
        let first = Block(order: 0, type: .paragraph, text: RichText(plainText: "A"), note: note)
        let second = Block(order: 1, type: .paragraph, text: RichText(plainText: "B"), note: note)
        note.blocks = [first, second]
        let range = BlockSelectionRange(single: first.id)

        let canMoveUp = BlockSelectionOperations.canMoveRange(range, in: note, by: -1)
        let canMoveDown = BlockSelectionOperations.canMoveRange(range, in: note, by: 1)

        #expect(canMoveUp == false)
        #expect(canMoveDown == true)
        // Aucune mutation : l'ordre reste inchange.
        #expect(BlockOrdering.topLevelBlocks(of: note).map { $0.text?.plainText } == ["A", "B"])
    }

    // MARK: - Conversion en lot

    @Test("convertRange(_:to:in:) convertit les blocs convertibles et ignore les autres")
    func convertRangeIgnoresNonConvertibleBlocks() {
        let note = Note(title: "Test")
        let paragraph = Block(order: 0, type: .paragraph, text: RichText(plainText: "Un"), note: note)
        let divider = Block(order: 1, type: .divider, note: note)
        let quote = Block(order: 2, type: .quote, text: RichText(plainText: "Deux"), note: note)
        note.blocks = [paragraph, divider, quote]

        BlockSelectionOperations.convertRange(
            BlockSelectionRange(anchorBlockID: paragraph.id, focusBlockID: quote.id), to: .bulletedList, in: note
        )

        #expect(paragraph.type == .bulletedList)
        #expect(divider.type == .divider) // ignore, jamais bloquant pour le reste
        #expect(quote.type == .bulletedList)
        #expect(paragraph.text?.plainText == "Un")
        #expect(quote.text?.plainText == "Deux")
    }

    @Test("hasAnyConvertibleBlock(in:note:) est vrai si au moins un bloc de la plage est convertible")
    func hasAnyConvertibleBlockDetectsAtLeastOne() {
        let note = Note(title: "Test")
        let divider = Block(order: 0, type: .divider, note: note)
        let paragraph = Block(order: 1, type: .paragraph, text: RichText(plainText: "Un"), note: note)
        note.blocks = [divider, paragraph]
        let range = BlockSelectionRange(anchorBlockID: divider.id, focusBlockID: paragraph.id)

        #expect(BlockSelectionOperations.hasAnyConvertibleBlock(in: range, note: note) == true)
    }

    @Test("hasAnyConvertibleBlock(in:note:) est faux si AUCUN bloc de la plage n'est convertible")
    func hasAnyConvertibleBlockIsFalseWhenNoneMatch() {
        let note = Note(title: "Test")
        let dividerA = Block(order: 0, type: .divider, note: note)
        let dividerB = Block(order: 1, type: .divider, note: note)
        note.blocks = [dividerA, dividerB]
        let range = BlockSelectionRange(anchorBlockID: dividerA.id, focusBlockID: dividerB.id)

        #expect(BlockSelectionOperations.hasAnyConvertibleBlock(in: range, note: note) == false)
    }
}
