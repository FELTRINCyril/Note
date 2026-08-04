import Foundation
import SlateModel
import Testing

@testable import SlateEditor

/// `BlockOrdering` : tri par `order` (jamais l'ordre d'insertion), calcul de la
/// profondeur d'imbrication, rang d'un item de liste numerotee.
@MainActor
struct BlockOrderingTests {
    @Test("Les blocs racine sont tries par order, pas par ordre d'insertion")
    func topLevelBlocksSortedByOrder() {
        let note = Note(title: "Test")
        let first = Block(order: 0, type: .paragraph, text: RichText(plainText: "Un"), note: note)
        let second = Block(order: 1, type: .paragraph, text: RichText(plainText: "Deux"), note: note)
        let third = Block(order: 2, type: .paragraph, text: RichText(plainText: "Trois"), note: note)
        note.blocks = [third, first, second] // insere volontairement dans le desordre

        let sorted = BlockOrdering.topLevelBlocks(of: note)

        #expect(sorted.map(\.order) == [0, 1, 2])
        #expect(sorted.map { $0.text?.plainText } == ["Un", "Deux", "Trois"])
    }

    @Test("Les blocs avec un parent sont exclus des blocs racine")
    func topLevelBlocksExcludesNestedBlocks() {
        let note = Note(title: "Test")
        let listRoot = Block(order: 0, type: .bulletedList, note: note)
        let nested = Block(order: 0, type: .bulletedList, note: note, parent: listRoot)
        note.blocks = [listRoot, nested]

        let topLevel = BlockOrdering.topLevelBlocks(of: note)

        #expect(topLevel.map(\.id) == [listRoot.id])
    }

    @Test("children(of:) trie les enfants directs par order")
    func childrenSortedByOrder() {
        let note = Note(title: "Test")
        let parent = Block(order: 0, type: .bulletedList, note: note)
        let childB = Block(order: 1, type: .bulletedList, text: RichText(plainText: "B"), note: note, parent: parent)
        let childA = Block(order: 0, type: .bulletedList, text: RichText(plainText: "A"), note: note, parent: parent)
        parent.children = [childB, childA]

        let children = BlockOrdering.children(of: parent)

        #expect(children.map { $0.text?.plainText } == ["A", "B"])
    }

    @Test("indentLevel(of:) vaut 0 pour un bloc racine")
    func indentLevelZeroForRootBlock() {
        let note = Note(title: "Test")
        let root = Block(order: 0, type: .paragraph, note: note)

        #expect(BlockOrdering.indentLevel(of: root) == 0)
    }

    @Test("indentLevel(of:) compte le nombre d'ancetres")
    func indentLevelCountsAncestors() {
        let note = Note(title: "Test")
        let root = Block(order: 0, type: .bulletedList, note: note)
        let child = Block(order: 0, type: .bulletedList, note: note, parent: root)
        let grandchild = Block(order: 0, type: .bulletedList, note: note, parent: child)

        #expect(BlockOrdering.indentLevel(of: root) == 0)
        #expect(BlockOrdering.indentLevel(of: child) == 1)
        #expect(BlockOrdering.indentLevel(of: grandchild) == 2)
    }

    @Test("numberedListRank(of:among:) numerote une serie contigue a partir de 1")
    func numberedListRankCountsContiguousRun() {
        let note = Note(title: "Test")
        let first = Block(order: 0, type: .numberedList, note: note)
        let second = Block(order: 1, type: .numberedList, note: note)
        let third = Block(order: 2, type: .numberedList, note: note)
        let siblings = [third, first, second]

        #expect(BlockOrdering.numberedListRank(of: first, among: siblings) == 1)
        #expect(BlockOrdering.numberedListRank(of: second, among: siblings) == 2)
        #expect(BlockOrdering.numberedListRank(of: third, among: siblings) == 3)
    }

    @Test("numberedListRank(of:among:) redemarre apres un bloc d'un autre type")
    func numberedListRankRestartsAfterInterruption() {
        let note = Note(title: "Test")
        let first = Block(order: 0, type: .numberedList, note: note)
        let interruption = Block(order: 1, type: .paragraph, note: note)
        let restarted = Block(order: 2, type: .numberedList, note: note)
        let siblings = [first, interruption, restarted]

        #expect(BlockOrdering.numberedListRank(of: first, among: siblings) == 1)
        #expect(BlockOrdering.numberedListRank(of: restarted, among: siblings) == 1)
    }
}
