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

    // MARK: - Ordre visuel complet (sous-etape 5.3 : navigation clavier haut/bas)

    @Test("flattenedBlocks(of:) suit l'ordre de lecture, y compris a travers l'imbrication")
    func flattenedBlocksFollowsReadingOrderThroughNesting() {
        let note = Note(title: "Test")
        let listRoot = Block(order: 0, type: .bulletedList, text: RichText(plainText: "Racine"), note: note)
        let nested = Block(
            order: 0, type: .bulletedList, text: RichText(plainText: "Enfant"), note: note, parent: listRoot
        )
        let after = Block(order: 1, type: .paragraph, text: RichText(plainText: "Apres"), note: note)
        listRoot.children = [nested]
        note.blocks = [after, listRoot, nested] // ordre d'insertion volontairement different

        let flat = BlockOrdering.flattenedBlocks(of: note)

        #expect(flat.map { $0.text?.plainText } == ["Racine", "Enfant", "Apres"])
    }

    @Test("block(before:) et block(after:) traversent l'imbrication d'une liste")
    func beforeAfterTraverseNesting() {
        let note = Note(title: "Test")
        let listRoot = Block(order: 0, type: .bulletedList, text: RichText(plainText: "Racine"), note: note)
        let nested = Block(
            order: 0, type: .bulletedList, text: RichText(plainText: "Enfant"), note: note, parent: listRoot
        )
        let after = Block(order: 1, type: .paragraph, text: RichText(plainText: "Apres"), note: note)
        listRoot.children = [nested]
        // `note.blocks` porte TOUS les blocs de la note (racine ET imbriques, c'est
        // l'inverse de `Block.note`) : omettre `nested` ici casserait sa relation
        // inverse au moment de l'affectation (voir la documentation de
        // `BlockOrdering.writeBack`).
        note.blocks = [listRoot, after, nested]

        #expect(BlockOrdering.block(before: nested)?.id == listRoot.id)
        #expect(BlockOrdering.block(after: nested)?.id == after.id)
    }

    @Test("block(before:) est nil pour le premier bloc de la note")
    func blockBeforeNilForFirstBlock() {
        let note = Note(title: "Test")
        let first = Block(order: 0, type: .paragraph, note: note)
        let second = Block(order: 1, type: .paragraph, note: note)
        note.blocks = [first, second]

        #expect(BlockOrdering.block(before: first) == nil)
    }

    @Test("block(after:) est nil pour le dernier bloc de la note")
    func blockAfterNilForLastBlock() {
        let note = Note(title: "Test")
        let first = Block(order: 0, type: .paragraph, note: note)
        let second = Block(order: 1, type: .paragraph, note: note)
        note.blocks = [first, second]

        #expect(BlockOrdering.block(after: second) == nil)
    }

    @Test("block(before:)/block(after:) sont nil pour un bloc sans note")
    func beforeAfterNilForOrphanBlock() {
        let orphan = Block(order: 0, type: .paragraph)

        #expect(BlockOrdering.block(before: orphan) == nil)
        #expect(BlockOrdering.block(after: orphan) == nil)
    }

    // MARK: - Mutations : insertion / suppression avec renumerotation

    @Test("insert(after:) place le nouveau bloc juste apres l'ancre et renumerote tous les freres")
    func insertAfterRenumbersSiblings() {
        let note = Note(title: "Test")
        let first = Block(order: 0, type: .paragraph, text: RichText(plainText: "Un"), note: note)
        let second = Block(order: 1, type: .paragraph, text: RichText(plainText: "Deux"), note: note)
        note.blocks = [first, second]
        let inserted = Block(type: .paragraph, text: RichText(plainText: "Nouveau"))

        BlockOrdering.insert(inserted, after: first)

        let blocks = BlockOrdering.topLevelBlocks(of: note)
        #expect(blocks.map { $0.text?.plainText } == ["Un", "Nouveau", "Deux"])
        #expect(blocks.map(\.order) == [0, 1, 2])
        #expect(inserted.note?.id == note.id)
    }

    @Test("insert(before:) place le nouveau bloc juste avant l'ancre")
    func insertBeforePlacesBlockAhead() {
        let note = Note(title: "Test")
        let only = Block(order: 0, type: .paragraph, text: RichText(plainText: "Seul"), note: note)
        note.blocks = [only]
        let inserted = Block(type: .paragraph, text: RichText(plainText: "Avant"))

        BlockOrdering.insert(inserted, before: only)

        let blocks = BlockOrdering.topLevelBlocks(of: note)
        #expect(blocks.map { $0.text?.plainText } == ["Avant", "Seul"])
        #expect(blocks.map(\.order) == [0, 1])
    }

    @Test("insert(after:) au sein d'une fratrie imbriquee reste dans le meme parent")
    func insertAfterWithinNestedSiblings() {
        let note = Note(title: "Test")
        let listRoot = Block(order: 0, type: .bulletedList, note: note)
        let firstChild = Block(
            order: 0, type: .bulletedList, text: RichText(plainText: "A"), note: note, parent: listRoot
        )
        listRoot.children = [firstChild]
        note.blocks = [listRoot]
        let inserted = Block(type: .bulletedList, text: RichText(plainText: "B"))

        BlockOrdering.insert(inserted, after: firstChild)

        let children = BlockOrdering.children(of: listRoot)
        #expect(children.map { $0.text?.plainText } == ["A", "B"])
        #expect(inserted.parent?.id == listRoot.id)
        #expect(BlockOrdering.topLevelBlocks(of: note).count == 1) // toujours un seul bloc racine
    }

    @Test("remove(_:) retire le bloc et renumerote les freres restants")
    func removeRenumbersRemainingSiblings() {
        let note = Note(title: "Test")
        let first = Block(order: 0, type: .paragraph, text: RichText(plainText: "Un"), note: note)
        let second = Block(order: 1, type: .paragraph, text: RichText(plainText: "Deux"), note: note)
        let third = Block(order: 2, type: .paragraph, text: RichText(plainText: "Trois"), note: note)
        note.blocks = [first, second, third]

        BlockOrdering.remove(second)

        let blocks = BlockOrdering.topLevelBlocks(of: note)
        #expect(blocks.map { $0.text?.plainText } == ["Un", "Trois"])
        #expect(blocks.map(\.order) == [0, 1])
        #expect(second.note == nil)
    }

    @Test("remove(_:) promeut les enfants directs du bloc supprime, a sa place exacte")
    func removePromotesChildrenInPlace() {
        let note = Note(title: "Test")
        let before = Block(order: 0, type: .paragraph, text: RichText(plainText: "Avant"), note: note)
        let removed = Block(order: 1, type: .bulletedList, note: note)
        let child = Block(
            order: 0, type: .bulletedList, text: RichText(plainText: "Enfant"), note: note, parent: removed
        )
        let after = Block(order: 2, type: .paragraph, text: RichText(plainText: "Apres"), note: note)
        removed.children = [child]
        note.blocks = [before, removed, after, child]

        BlockOrdering.remove(removed)

        let topLevel = BlockOrdering.topLevelBlocks(of: note)
        #expect(topLevel.map(\.id) == [before.id, child.id, after.id])
        #expect(child.parent == nil)
        #expect(child.note?.id == note.id)
        #expect(topLevel.map(\.order) == [0, 1, 2])
    }
}
