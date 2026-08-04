import Foundation
import SlateModel
import Testing

@testable import SlateEditor

/// `BlockLifecycle` : logique PURE (aucun AppKit, aucun `ModelContext`) du cycle de vie
/// des blocs au clavier (docs/05_editeur_blocs.md, sous-etape 5.3). Ces tests construisent
/// des `Note`/`Block` en memoire, exactement comme `BlockOrderingTests` -- c'est la
/// demonstration directe que cette logique est testable hors AppKit.
@MainActor
@Suite("BlockLifecycle")
struct BlockLifecycleTests {
    // MARK: - Entree

    @Test("Entree en fin de bloc cree un nouveau bloc en dessous et y deplace le focus")
    func enterAtEndCreatesBlockBelow() {
        let note = Note(title: "Test")
        let block = Block(order: 0, type: .paragraph, text: RichText(plainText: "Bonjour"), note: note)
        note.blocks = [block]

        let request = BlockLifecycle.handleEnter(in: block, caretOffset: 7)

        let blocks = BlockOrdering.topLevelBlocks(of: note)
        #expect(blocks.count == 2)
        #expect(blocks[0].id == block.id)
        #expect(blocks[1].type == .paragraph)
        #expect(blocks[1].text?.isEmpty == true)
        #expect(blocks.map(\.order) == [0, 1])
        #expect(request == EditorCaretRequest(blockID: blocks[1].id, placement: .offset(0)))
    }

    @Test("Entree en fin d'un item de liste cree un nouvel item de la MEME liste")
    func enterAtEndOfListItemInheritsType() {
        let note = Note(title: "Test")
        let item = Block(order: 0, type: .bulletedList, text: RichText(plainText: "Item"), note: note)
        note.blocks = [item]

        _ = BlockLifecycle.handleEnter(in: item, caretOffset: 4)

        let blocks = BlockOrdering.topLevelBlocks(of: note)
        #expect(blocks[1].type == .bulletedList)
    }

    @Test("Entree sur un item de liste VIDE convertit l'item en paragraphe")
    func enterOnEmptyListItemConvertsToParagraph() {
        let note = Note(title: "Test")
        let item = Block(order: 0, type: .todo, text: RichText(), note: note)
        note.blocks = [item]

        let request = BlockLifecycle.handleEnter(in: item, caretOffset: 0)

        #expect(item.type == .paragraph)
        #expect(BlockOrdering.topLevelBlocks(of: note).count == 1)
        #expect(request == EditorCaretRequest(blockID: item.id, placement: .offset(0)))
    }

    @Test("Entree sur un paragraphe VIDE ne le convertit pas (deja un paragraphe)")
    func enterOnEmptyParagraphStaysParagraph() {
        let note = Note(title: "Test")
        let block = Block(order: 0, type: .paragraph, text: RichText(), note: note)
        note.blocks = [block]

        _ = BlockLifecycle.handleEnter(in: block, caretOffset: 0)

        #expect(block.type == .paragraph)
        #expect(BlockOrdering.topLevelBlocks(of: note).count == 1)
    }

    @Test("Entree en debut de bloc NON vide insere un bloc vide au-dessus, garde le focus courant")
    func enterAtStartOfNonEmptyBlockInsertsAbove() {
        let note = Note(title: "Test")
        let block = Block(order: 0, type: .paragraph, text: RichText(plainText: "Bonjour"), note: note)
        note.blocks = [block]

        let request = BlockLifecycle.handleEnter(in: block, caretOffset: 0)

        let blocks = BlockOrdering.topLevelBlocks(of: note)
        #expect(blocks.count == 2)
        #expect(blocks[0].text?.isEmpty == true)
        #expect(blocks[1].id == block.id)
        #expect(blocks[1].text?.plainText == "Bonjour")
        #expect(request == EditorCaretRequest(blockID: block.id, placement: .offset(0)))
    }

    @Test("Entree au milieu d'un bloc scinde le contenu en preservant les attributs des deux moities")
    func enterInMiddleSplitsPreservingAttributes() {
        let note = Note(title: "Test")
        var text = RichText(plainText: "Bonjour le monde")
        text.apply(.bold, to: text.range(charactersOffset: 0..<7))
        let block = Block(order: 0, type: .paragraph, text: text, note: note)
        note.blocks = [block]

        let request = BlockLifecycle.handleEnter(in: block, caretOffset: 7)

        let blocks = BlockOrdering.topLevelBlocks(of: note)
        #expect(blocks.count == 2)
        #expect(blocks[0].text?.plainText == "Bonjour")
        #expect(blocks[0].text?.attributedString.runs.first?.inlinePresentationIntent == .stronglyEmphasized)
        #expect(blocks[1].text?.plainText == " le monde")
        #expect(blocks[1].type == .paragraph)
        #expect(request == EditorCaretRequest(blockID: blocks[1].id, placement: .offset(0)))
    }

    @Test("Le split d'un item de liste coche cree deux items coches (attributs copies)")
    func splitOfCheckedTodoCopiesAttributes() {
        let note = Note(title: "Test")
        let attributes = BlockAttributes(isChecked: true)
        let item = Block(
            order: 0, type: .todo, text: RichText(plainText: "Acheter du pain"), attributes: attributes, note: note
        )
        note.blocks = [item]

        _ = BlockLifecycle.handleEnter(in: item, caretOffset: 7)

        let blocks = BlockOrdering.topLevelBlocks(of: note)
        #expect(blocks[0].type == .todo)
        #expect(blocks[0].attributes.isChecked == true)
        #expect(blocks[1].type == .todo)
        #expect(blocks[1].attributes.isChecked == true)
    }

    @Test("Entree recalcule les order de tous les blocs suivants")
    func enterRenumbersFollowingBlocks() {
        let note = Note(title: "Test")
        let first = Block(order: 0, type: .paragraph, text: RichText(plainText: "Un"), note: note)
        let second = Block(order: 1, type: .paragraph, text: RichText(plainText: "Deux"), note: note)
        note.blocks = [first, second]

        _ = BlockLifecycle.handleEnter(in: first, caretOffset: 2)

        let blocks = BlockOrdering.topLevelBlocks(of: note)
        #expect(blocks.map { $0.text?.plainText } == ["Un", "", "Deux"])
        #expect(blocks.map(\.order) == [0, 1, 2])
    }

    // MARK: - Retour arriere

    @Test("Retour arriere sur un bloc VIDE le supprime et place le focus en fin du precedent")
    func backspaceOnEmptyBlockDeletesAndFocusesPreviousEnd() {
        let note = Note(title: "Test")
        let previous = Block(order: 0, type: .paragraph, text: RichText(plainText: "Bonjour"), note: note)
        let empty = Block(order: 1, type: .paragraph, text: RichText(), note: note)
        note.blocks = [previous, empty]

        let request = BlockLifecycle.handleBackspaceAtStart(in: empty)

        #expect(BlockOrdering.topLevelBlocks(of: note).map(\.id) == [previous.id])
        #expect(empty.note == nil)
        #expect(request == EditorCaretRequest(blockID: previous.id, placement: .offset(7)))
    }

    @Test("Retour arriere fusionne les contenus, attributs preserves des deux cotes, caret a la jointure")
    func backspaceMergesPreservingAttributesAtJoint() {
        let note = Note(title: "Test")
        var previousText = RichText(plainText: "Bonjour")
        previousText.apply(.bold, to: previousText.range(charactersOffset: 0..<7))
        let previous = Block(order: 0, type: .paragraph, text: previousText, note: note)

        var currentText = RichText(plainText: " le monde")
        currentText.apply(.italic, to: currentText.range(charactersOffset: 0..<3))
        let current = Block(order: 1, type: .paragraph, text: currentText, note: note)
        note.blocks = [previous, current]

        let request = BlockLifecycle.handleBackspaceAtStart(in: current)

        #expect(BlockOrdering.topLevelBlocks(of: note).map(\.id) == [previous.id])
        #expect(previous.text?.plainText == "Bonjour le monde")
        #expect(previous.text?.attributedString.runs.first?.inlinePresentationIntent == .stronglyEmphasized)
        let italicRun = previous.text?.attributedString.runs.first { $0.inlinePresentationIntent == .emphasized }
        #expect(italicRun != nil)
        #expect(request == EditorCaretRequest(blockID: previous.id, placement: .offset(7)))
    }

    @Test("Retour arriere sur le PREMIER bloc de la note ne fait rien : aucune perte, note toujours editable")
    func backspaceOnFirstBlockIsNoOp() {
        let note = Note(title: "Test")
        let onlyBlock = Block(order: 0, type: .paragraph, text: RichText(plainText: "Seul"), note: note)
        note.blocks = [onlyBlock]

        let request = BlockLifecycle.handleBackspaceAtStart(in: onlyBlock)

        #expect(request == nil)
        #expect(BlockOrdering.topLevelBlocks(of: note).count == 1)
        #expect(onlyBlock.text?.plainText == "Seul")
    }

    @Test("Retour arriere avec un bloc precedent NON textuel (divider) le retire, caret inchange")
    func backspaceWithNonTextPreviousRemovesIt() {
        let note = Note(title: "Test")
        let divider = Block(order: 0, type: .divider, note: note)
        let paragraph = Block(order: 1, type: .paragraph, text: RichText(plainText: "Texte"), note: note)
        note.blocks = [divider, paragraph]

        let request = BlockLifecycle.handleBackspaceAtStart(in: paragraph)

        #expect(BlockOrdering.topLevelBlocks(of: note).map(\.id) == [paragraph.id])
        #expect(paragraph.text?.plainText == "Texte")
        #expect(request == EditorCaretRequest(blockID: paragraph.id, placement: .offset(0)))
    }

    @Test("Suppression d'un bloc avec enfants : les enfants sont promus, aucune perte de contenu")
    func backspaceDeletingParentPromotesChildren() {
        let note = Note(title: "Test")
        let previous = Block(order: 0, type: .paragraph, text: RichText(plainText: "Avant"), note: note)
        let emptyListItem = Block(order: 1, type: .bulletedList, text: RichText(), note: note)
        let child = Block(
            order: 0, type: .bulletedList, text: RichText(plainText: "Enfant"), note: note, parent: emptyListItem
        )
        emptyListItem.children = [child]
        note.blocks = [previous, emptyListItem, child]

        _ = BlockLifecycle.handleBackspaceAtStart(in: emptyListItem)

        let topLevel = BlockOrdering.topLevelBlocks(of: note)
        #expect(topLevel.map(\.id) == [previous.id, child.id])
        #expect(child.parent == nil)
        #expect(child.text?.plainText == "Enfant")
    }

    @Test("Retour arriere recalcule les order des blocs restants")
    func backspaceRenumbersRemainingBlocks() {
        let note = Note(title: "Test")
        let first = Block(order: 0, type: .paragraph, text: RichText(plainText: "Un"), note: note)
        let empty = Block(order: 1, type: .paragraph, text: RichText(), note: note)
        let third = Block(order: 2, type: .paragraph, text: RichText(plainText: "Trois"), note: note)
        note.blocks = [first, empty, third]

        _ = BlockLifecycle.handleBackspaceAtStart(in: empty)

        let blocks = BlockOrdering.topLevelBlocks(of: note)
        #expect(blocks.map { $0.text?.plainText } == ["Un", "Trois"])
        #expect(blocks.map(\.order) == [0, 1])
    }
}
