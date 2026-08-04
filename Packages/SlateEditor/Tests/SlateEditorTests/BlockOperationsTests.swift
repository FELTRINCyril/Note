import Foundation
import SlateModel
import Testing

@testable import SlateEditor

/// `BlockOperations` : duplication (avec enfants et attributs), suppression (garantie
/// de non-vacuite de la note), deplacement parmi les freres de meme niveau (sous-etape
/// 5.4, menu de bloc). Aucun `NSTextView`/`ModelContext` : uniquement des `Note`/`Block`
/// en memoire, comme `BlockOrderingTests`/`BlockLifecycleTests`.
@MainActor
@Suite("BlockOperations")
struct BlockOperationsTests {
    // MARK: - Duplication

    @Test("duplicate(_:) insere le double juste apres l'original et renumerote la fratrie")
    func duplicateInsertsRightAfterOriginal() {
        let note = Note(title: "Test")
        let first = Block(order: 0, type: .paragraph, text: RichText(plainText: "Un"), note: note)
        let second = Block(order: 1, type: .paragraph, text: RichText(plainText: "Deux"), note: note)
        note.blocks = [first, second]

        let copy = BlockOperations.duplicate(first)

        let blocks = BlockOrdering.topLevelBlocks(of: note)
        #expect(blocks.map { $0.text?.plainText } == ["Un", "Un", "Deux"])
        #expect(blocks.map(\.order) == [0, 1, 2])
        #expect(blocks[1].id == copy.id)
        #expect(copy.id != first.id)
    }

    @Test("duplicate(_:) copie le type, le texte et les attributs sans partager l'instance")
    func duplicatePreservesTextAndAttributes() {
        let note = Note(title: "Test")
        var attributes = BlockAttributes()
        attributes.isChecked = true
        let original = Block(
            order: 0, type: .todo, text: RichText(plainText: "Acheter du pain"), attributes: attributes, note: note
        )
        note.blocks = [original]

        let copy = BlockOperations.duplicate(original)

        #expect(copy.type == .todo)
        #expect(copy.text?.plainText == "Acheter du pain")
        #expect(copy.attributes.isChecked == true)

        // Muter l'original APRES duplication ne doit jamais affecter le double (RichText/
        // BlockAttributes sont des `struct`, copiees par valeur -- pas de partage
        // d'instance accidentel).
        original.text = RichText(plainText: "Modifie")
        original.attributes.isChecked = false
        #expect(copy.text?.plainText == "Acheter du pain")
        #expect(copy.attributes.isChecked == true)
    }

    @Test("duplicate(_:) duplique recursivement les enfants, memes types/textes, nouveaux identifiants")
    func duplicateDuplicatesChildrenRecursively() {
        let note = Note(title: "Test")
        let list = Block(order: 0, type: .bulletedList, note: note)
        let childA = Block(order: 0, type: .bulletedList, text: RichText(plainText: "A"), note: note, parent: list)
        let childB = Block(order: 1, type: .bulletedList, text: RichText(plainText: "B"), note: note, parent: list)
        list.children = [childA, childB]
        let grandchild = Block(
            order: 0, type: .bulletedList, text: RichText(plainText: "A.1"), note: note, parent: childA
        )
        childA.children = [grandchild]
        note.blocks = [list, childA, childB, grandchild]

        let copy = BlockOperations.duplicate(list)

        let copiedChildren = BlockOrdering.children(of: copy)
        #expect(copiedChildren.map { $0.text?.plainText } == ["A", "B"])
        #expect(copiedChildren.map(\.id).contains(childA.id) == false) // nouveaux identifiants

        let copiedGrandchildren = BlockOrdering.children(of: copiedChildren[0])
        #expect(copiedGrandchildren.map { $0.text?.plainText } == ["A.1"])
        #expect(copiedChildren[0].parent?.id == copy.id)
        #expect(copiedGrandchildren[0].parent?.id == copiedChildren[0].id)

        // L'original garde ses propres enfants, inchanges.
        #expect(BlockOrdering.children(of: list).map(\.id) == [childA.id, childB.id])
    }

    // MARK: - Suppression

    @Test("remove(_:from:) retire le bloc et renumerote les freres restants")
    func removeRenumbersRemainingSiblings() {
        let note = Note(title: "Test")
        let first = Block(order: 0, type: .paragraph, text: RichText(plainText: "Un"), note: note)
        let second = Block(order: 1, type: .paragraph, text: RichText(plainText: "Deux"), note: note)
        let third = Block(order: 2, type: .paragraph, text: RichText(plainText: "Trois"), note: note)
        note.blocks = [first, second, third]

        BlockOperations.remove(second, from: note)

        let blocks = BlockOrdering.topLevelBlocks(of: note)
        #expect(blocks.map { $0.text?.plainText } == ["Un", "Trois"])
        #expect(blocks.map(\.order) == [0, 1])
    }

    @Test("remove(_:from:) promeut les enfants du bloc supprime, comme BlockOrdering.remove(_:)")
    func removePromotesChildren() {
        let note = Note(title: "Test")
        let removed = Block(order: 0, type: .bulletedList, note: note)
        let child = Block(
            order: 0, type: .bulletedList, text: RichText(plainText: "Enfant"), note: note, parent: removed
        )
        removed.children = [child]
        note.blocks = [removed, child]

        BlockOperations.remove(removed, from: note)

        let topLevel = BlockOrdering.topLevelBlocks(of: note)
        #expect(topLevel.map(\.id) == [child.id])
        #expect(child.parent == nil)
    }

    @Test("remove(_:from:) sur le dernier bloc de la note insere un paragraphe vide de secours")
    func removeLastBlockKeepsNoteEditable() {
        let note = Note(title: "Test")
        let only = Block(order: 0, type: .paragraph, text: RichText(plainText: "Seul"), note: note)
        note.blocks = [only]

        BlockOperations.remove(only, from: note)

        let blocks = BlockOrdering.topLevelBlocks(of: note)
        #expect(blocks.count == 1)
        #expect(blocks[0].id != only.id)
        #expect(blocks[0].type == .paragraph)
        #expect(blocks[0].text?.isEmpty == true)
    }

    @Test("remove(_:from:) sur le dernier bloc SANS enfant a promouvoir insere aussi un paragraphe de secours")
    func removeLastBlockWithoutChildrenKeepsNoteEditable() {
        let note = Note(title: "Test")
        let onlyDivider = Block(order: 0, type: .divider, note: note)
        note.blocks = [onlyDivider]

        BlockOperations.remove(onlyDivider, from: note)

        let blocks = BlockOrdering.topLevelBlocks(of: note)
        #expect(blocks.count == 1)
        #expect(blocks[0].type == .paragraph)
    }

    // MARK: - Deplacement parmi les freres de meme niveau

    @Test("moveUp(_:) echange l'ordre avec le frere precedent")
    func moveUpSwapsWithPreviousSibling() {
        let note = Note(title: "Test")
        let first = Block(order: 0, type: .paragraph, text: RichText(plainText: "Un"), note: note)
        let second = Block(order: 1, type: .paragraph, text: RichText(plainText: "Deux"), note: note)
        let third = Block(order: 2, type: .paragraph, text: RichText(plainText: "Trois"), note: note)
        note.blocks = [first, second, third]

        let moved = BlockOperations.moveUp(third)

        #expect(moved == true)
        let blocks = BlockOrdering.topLevelBlocks(of: note)
        #expect(blocks.map { $0.text?.plainText } == ["Un", "Trois", "Deux"])
        #expect(blocks.map(\.order) == [0, 1, 2])
    }

    @Test("moveDown(_:) echange l'ordre avec le frere suivant")
    func moveDownSwapsWithNextSibling() {
        let note = Note(title: "Test")
        let first = Block(order: 0, type: .paragraph, text: RichText(plainText: "Un"), note: note)
        let second = Block(order: 1, type: .paragraph, text: RichText(plainText: "Deux"), note: note)
        note.blocks = [first, second]

        let moved = BlockOperations.moveDown(first)

        #expect(moved == true)
        let blocks = BlockOrdering.topLevelBlocks(of: note)
        #expect(blocks.map { $0.text?.plainText } == ["Deux", "Un"])
        #expect(blocks.map(\.order) == [0, 1])
    }

    @Test("moveUp(_:) sur le premier bloc de la fratrie ne fait rien")
    func moveUpOnFirstBlockDoesNothing() {
        let note = Note(title: "Test")
        let first = Block(order: 0, type: .paragraph, text: RichText(plainText: "Un"), note: note)
        let second = Block(order: 1, type: .paragraph, text: RichText(plainText: "Deux"), note: note)
        note.blocks = [first, second]

        let moved = BlockOperations.moveUp(first)

        #expect(moved == false)
        #expect(BlockOrdering.topLevelBlocks(of: note).map { $0.text?.plainText } == ["Un", "Deux"])
    }

    @Test("moveDown(_:) sur le dernier bloc de la fratrie ne fait rien")
    func moveDownOnLastBlockDoesNothing() {
        let note = Note(title: "Test")
        let first = Block(order: 0, type: .paragraph, text: RichText(plainText: "Un"), note: note)
        let second = Block(order: 1, type: .paragraph, text: RichText(plainText: "Deux"), note: note)
        note.blocks = [first, second]

        let moved = BlockOperations.moveDown(second)

        #expect(moved == false)
        #expect(BlockOrdering.topLevelBlocks(of: note).map { $0.text?.plainText } == ["Un", "Deux"])
    }

    @Test("moveUp(_:)/moveDown(_:) restent restreints aux freres de meme niveau (imbrication ignoree)")
    func moveStaysWithinSameLevelSiblings() {
        let note = Note(title: "Test")
        let list = Block(order: 0, type: .bulletedList, note: note)
        let child = Block(order: 0, type: .bulletedList, text: RichText(plainText: "Enfant"), note: note, parent: list)
        list.children = [child]
        let after = Block(order: 1, type: .paragraph, text: RichText(plainText: "Apres"), note: note)
        note.blocks = [list, after, child]

        // `child` est seul parmi les enfants de `list` : aucun mouvement possible, et
        // surtout aucune sortie vers la fratrie racine (`list`/`after`).
        let movedUp = BlockOperations.moveUp(child)
        let movedDown = BlockOperations.moveDown(child)

        #expect(movedUp == false)
        #expect(movedDown == false)
        #expect(child.parent?.id == list.id)
    }
}
