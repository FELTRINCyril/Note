import Foundation
import SlateModel
import Testing

@testable import SlateEditor

/// `BlockIndentation` : Tab/Maj+Tab sur un item de liste (docs/08_blocs_speciaux.md,
/// "Imbrication"). Construit des `Note`/`Block` en memoire, sans `ModelContext` ni
/// `NSTextView` -- meme motif que `BlockLifecycleTests`/`BlockOrderingTests`.
@MainActor
@Suite("BlockIndentation")
struct BlockIndentationTests {
    @Test("indent(_:) fait passer l'item enfant du frere precedent, garde son propre sous-arbre")
    func indentMovesUnderPreviousSibling() {
        let note = Note(title: "Test")
        let first = Block(order: 0, type: .bulletedList, text: RichText(plainText: "Un"), note: note)
        let second = Block(order: 1, type: .bulletedList, text: RichText(plainText: "Deux"), note: note)
        let childOfSecond = Block(
            order: 0, type: .bulletedList, text: RichText(plainText: "Deux.a"), note: note, parent: second
        )
        note.blocks = [first, second, childOfSecond]

        let result = BlockIndentation.indent(second)

        #expect(result)
        #expect(second.parent?.id == first.id)
        #expect(BlockOrdering.topLevelBlocks(of: note).map(\.id) == [first.id])
        #expect(BlockOrdering.children(of: first).map(\.id) == [second.id])
        // Le sous-arbre de `second` (son propre enfant) suit intact, pas promu.
        #expect(BlockOrdering.children(of: second).map(\.id) == [childOfSecond.id])
        #expect(childOfSecond.parent?.id == second.id)
    }

    @Test("indent(_:) est sans effet sur le premier item d'une fratrie (pas de frere precedent)")
    func indentNoOpOnFirstSibling() {
        let note = Note(title: "Test")
        let first = Block(order: 0, type: .bulletedList, text: RichText(plainText: "Un"), note: note)
        let second = Block(order: 1, type: .bulletedList, text: RichText(plainText: "Deux"), note: note)
        note.blocks = [first, second]

        let result = BlockIndentation.indent(first)

        #expect(!result)
        #expect(first.parent == nil)
    }

    @Test("indent(_:) est sans effet sur un type qui n'est pas un item de liste")
    func indentNoOpOnNonListType() {
        let note = Note(title: "Test")
        let first = Block(order: 0, type: .paragraph, text: RichText(plainText: "Un"), note: note)
        let second = Block(order: 1, type: .paragraph, text: RichText(plainText: "Deux"), note: note)
        note.blocks = [first, second]

        #expect(!BlockIndentation.indent(second))
        #expect(second.parent == nil)
    }

    @Test("outdent(_:) remonte l'item d'un niveau, juste apres son ancien parent")
    func outdentMovesAfterFormerParent() {
        let note = Note(title: "Test")
        let parent = Block(order: 0, type: .bulletedList, text: RichText(plainText: "Parent"), note: note)
        let child = Block(
            order: 0, type: .bulletedList, text: RichText(plainText: "Enfant"), note: note, parent: parent
        )
        let trailing = Block(order: 1, type: .bulletedList, text: RichText(plainText: "Apres"), note: note)
        note.blocks = [parent, child, trailing]

        let result = BlockIndentation.outdent(child)

        #expect(result)
        #expect(child.parent == nil)
        #expect(BlockOrdering.topLevelBlocks(of: note).map(\.id) == [parent.id, child.id, trailing.id])
    }

    @Test("outdent(_:) garde le sous-arbre de l'item intact")
    func outdentPreservesOwnChildren() {
        let note = Note(title: "Test")
        let parent = Block(order: 0, type: .bulletedList, note: note)
        let child = Block(order: 0, type: .bulletedList, note: note, parent: parent)
        let grandchild = Block(order: 0, type: .bulletedList, note: note, parent: child)
        note.blocks = [parent, child, grandchild]

        #expect(BlockIndentation.outdent(child))
        #expect(BlockOrdering.children(of: child).map(\.id) == [grandchild.id])
        #expect(grandchild.parent?.id == child.id)
    }

    @Test("outdent(_:) est sans effet sur un item deja au niveau racine")
    func outdentNoOpAtRootLevel() {
        let note = Note(title: "Test")
        let root = Block(order: 0, type: .todo, text: RichText(plainText: "Racine"), note: note)
        note.blocks = [root]

        #expect(!BlockIndentation.outdent(root))
    }

    @Test("outdent(_:) est sans effet sur un type qui n'est pas un item de liste")
    func outdentNoOpOnNonListType() {
        let note = Note(title: "Test")
        let parent = Block(order: 0, type: .paragraph, note: note)
        let child = Block(order: 0, type: .paragraph, note: note, parent: parent)
        note.blocks = [parent, child]

        #expect(!BlockIndentation.outdent(child))
        #expect(child.parent?.id == parent.id)
    }

    @Test("indent puis outdent sont symmetriques : l'item retrouve son niveau/position d'origine")
    func indentThenOutdentRoundTrips() {
        let note = Note(title: "Test")
        let first = Block(order: 0, type: .numberedList, note: note)
        let second = Block(order: 1, type: .numberedList, note: note)
        note.blocks = [first, second]

        #expect(BlockIndentation.indent(second))
        #expect(BlockIndentation.outdent(second))

        #expect(second.parent == nil)
        #expect(BlockOrdering.topLevelBlocks(of: note).map(\.id) == [first.id, second.id])
    }
}
