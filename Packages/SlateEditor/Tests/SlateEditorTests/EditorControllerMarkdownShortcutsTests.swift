import Foundation
import SlateModel
import SwiftData
import Testing

@testable import SlateEditor

/// `EditorController.handleMarkdownAutoformat`/`handleMarkdownReturnTrigger`
/// (docs/15_markdown_natif.md) : conversion de bloc/formatage inline, consommation de
/// la syntaxe, faux positifs, et annulation en UNE SEULE etape via un `UndoManager`
/// Foundation nu -- voir la documentation de tete de `EditorController+MarkdownShortcuts.swift`
/// pour le raisonnement complet sur `UndoManager.groupsByEvent`.
///
/// Meme regle que le reste de `EditorControllerTests` : aucun `NSTextView`, uniquement
/// une `Note`/`Block` en memoire. `UndoManager()` est un type Foundation ordinaire,
/// instanciable sans fenetre.
@MainActor
@Suite("EditorController.MarkdownShortcuts")
struct EditorControllerMarkdownShortcutsTests {
    private struct Fixture {
        let note: Note
        let block: Block
        let controller: EditorController
    }

    private func makeBlock(_ text: String, type: BlockType = .paragraph) -> Fixture {
        let note = Note(title: "Test")
        let block = Block(order: 0, type: type, text: RichText(plainText: text), note: note)
        note.blocks = [block]
        return Fixture(note: note, block: block, controller: EditorController(note: note))
    }

    // MARK: - Declencheurs de bloc a l'espace : conversion + consommation de la syntaxe

    @Test("\"# \" convertit le bloc en H1 et retire le marqueur")
    func headingConversionConsumesMarker() {
        let fixture = makeBlock("# ")
        let handled = fixture.controller.handleMarkdownAutoformat(
            in: fixture.block, typedText: RichText(plainText: "# "), caretOffset: 2, undoManager: nil
        )

        #expect(handled)
        #expect(fixture.block.type == .heading1)
        #expect(fixture.block.text?.plainText.isEmpty == true)
    }

    @Test("\"- \" convertit en liste a puces, le contenu APRES le marqueur est preserve")
    func bulletedListConversionPreservesTrailingContent() {
        let fixture = makeBlock("- Lait")
        let handled = fixture.controller.handleMarkdownAutoformat(
            in: fixture.block, typedText: RichText(plainText: "- Lait"), caretOffset: 2, undoManager: nil
        )

        #expect(handled)
        #expect(fixture.block.type == .bulletedList)
        #expect(fixture.block.text?.plainText == "Lait")
    }

    @Test("\"[x] \" convertit en tache COCHEE")
    func checkedTodoConversion() {
        let fixture = makeBlock("[x] ")
        let handled = fixture.controller.handleMarkdownAutoformat(
            in: fixture.block, typedText: RichText(plainText: "[x] "), caretOffset: 4, undoManager: nil
        )

        #expect(handled)
        #expect(fixture.block.type == .todo)
        #expect(fixture.block.attributes.isChecked)
    }

    @Test("\"[] \" convertit en tache NON cochee")
    func uncheckedTodoConversion() {
        let fixture = makeBlock("[] ")
        let handled = fixture.controller.handleMarkdownAutoformat(
            in: fixture.block, typedText: RichText(plainText: "[] "), caretOffset: 3, undoManager: nil
        )

        #expect(handled)
        #expect(fixture.block.type == .todo)
        #expect(fixture.block.attributes.isChecked == false)
    }

    @Test("\"> \" convertit en citation")
    func quoteConversion() {
        let fixture = makeBlock("> ")
        let handled = fixture.controller.handleMarkdownAutoformat(
            in: fixture.block, typedText: RichText(plainText: "> "), caretOffset: 2, undoManager: nil
        )

        #expect(handled)
        #expect(fixture.block.type == .quote)
    }

    @Test("\"1. \" convertit en liste numerotee")
    func numberedListConversion() {
        let fixture = makeBlock("1. ")
        let handled = fixture.controller.handleMarkdownAutoformat(
            in: fixture.block, typedText: RichText(plainText: "1. "), caretOffset: 3, undoManager: nil
        )

        #expect(handled)
        #expect(fixture.block.type == .numberedList)
    }

    @Test("Le caret est repositionne en debut de contenu apres conversion")
    func caretIsRepositionedAfterConversion() {
        let fixture = makeBlock("# Titre")
        fixture.controller.handleMarkdownAutoformat(
            in: fixture.block, typedText: RichText(plainText: "# Titre"), caretOffset: 2, undoManager: nil
        )

        let request = fixture.controller.consumePendingCaretRequest(for: fixture.block.id)
        #expect(request?.placement == .offset(0))
    }

    // MARK: - Declencheurs de bloc a l'Entree

    @Test("\"```\" + Entree convertit en bloc de code et vide le texte")
    func codeBlockReturnTrigger() {
        let fixture = makeBlock("```")
        let handled = fixture.controller.handleMarkdownReturnTrigger(in: fixture.block, undoManager: nil)

        #expect(handled)
        #expect(fixture.block.type == .code)
        #expect(fixture.block.text?.isEmpty == true)
    }

    @Test("\"---\" + Entree convertit en separateur et insere un paragraphe vide focalise")
    func dividerReturnTrigger() {
        let fixture = makeBlock("---")
        let handled = fixture.controller.handleMarkdownReturnTrigger(in: fixture.block, undoManager: nil)

        #expect(handled)
        #expect(fixture.block.type == .divider)
        let siblings = BlockOrdering.topLevelBlocks(of: fixture.note)
        #expect(siblings.count == 2)
        #expect(siblings[1].type == .paragraph)
        #expect(fixture.controller.focusedBlockID == siblings[1].id)
    }

    // MARK: - Faux positifs : rien ne se declenche

    @Test("Bloc non paragraphe : aucun declencheur d'espace n'agit")
    func nonParagraphBlockIgnoresSpaceTriggers() {
        let fixture = makeBlock("# ", type: .quote)
        let handled = fixture.controller.handleMarkdownAutoformat(
            in: fixture.block, typedText: RichText(plainText: "# "), caretOffset: 2, undoManager: nil
        )

        #expect(handled == false)
        #expect(fixture.block.type == .quote)
    }

    @Test("Bloc de code : le markdown inline n'est jamais interprete a l'interieur")
    func codeBlockNeverInterpretsInlineMarkdown() {
        let fixture = makeBlock("**gras**", type: .code)
        let handled = fixture.controller.handleMarkdownAutoformat(
            in: fixture.block, typedText: RichText(plainText: "**gras**"), caretOffset: 8, undoManager: nil
        )

        #expect(handled == false)
    }

    @Test("\"---\" au milieu d'un bloc non vide n'est jamais un separateur")
    func dividerDoesNotTriggerInNonEmptyBlock() {
        let fixture = makeBlock("Un texte ---")
        let handled = fixture.controller.handleMarkdownReturnTrigger(in: fixture.block, undoManager: nil)

        #expect(handled == false)
        #expect(fixture.block.type == .paragraph)
    }

    // MARK: - Formatage inline : conversion + consommation de la syntaxe

    @Test("**gras** applique le gras et retire les quatre asterisques")
    func boldConsumesDelimiters() throws {
        let fixture = makeBlock("**gras**")
        let handled = fixture.controller.handleMarkdownAutoformat(
            in: fixture.block, typedText: RichText(plainText: "**gras**"), caretOffset: 8, undoManager: nil
        )

        #expect(handled)
        #expect(fixture.block.text?.plainText == "gras")
        let text = try #require(fixture.block.text)
        let range = text.range(charactersOffset: 0..<4)
        #expect(FormattingEngine.isMarkActive(.bold, in: text, range: range))
    }

    @Test("*italique* applique l'italique et retire les deux asterisques")
    func italicConsumesDelimiters() throws {
        let fixture = makeBlock("*italique*")
        let handled = fixture.controller.handleMarkdownAutoformat(
            in: fixture.block, typedText: RichText(plainText: "*italique*"), caretOffset: 10, undoManager: nil
        )

        #expect(handled)
        #expect(fixture.block.text?.plainText == "italique")
        let text = try #require(fixture.block.text)
        let range = text.range(charactersOffset: 0..<8)
        #expect(FormattingEngine.isMarkActive(.italic, in: text, range: range))
    }

    @Test("Texte avant/apres le formatage inline est preserve")
    func inlineFormattingPreservesSurroundingText() {
        let fixture = makeBlock("avant **gras** apres")
        fixture.controller.handleMarkdownAutoformat(
            in: fixture.block, typedText: RichText(plainText: "avant **gras** apres"), caretOffset: 14, undoManager: nil
        )

        #expect(fixture.block.text?.plainText == "avant gras apres")
    }

    // MARK: - Annulation en une seule etape (`UndoManager` Foundation, sans fenetre)

    @Test("Annuler une conversion de titre restaure le texte ET le type en une seule etape")
    func undoRestoresTextAndTypeTogether() {
        let fixture = makeBlock("# ")
        let undoManager = UndoManager()

        fixture.controller.handleMarkdownAutoformat(
            in: fixture.block, typedText: RichText(plainText: "# "), caretOffset: 2, undoManager: undoManager
        )
        #expect(fixture.block.type == .heading1)

        undoManager.undo()

        #expect(fixture.block.type == .paragraph)
        #expect(fixture.block.text?.plainText == "# ")
    }

    @Test("Retablir apres annulation reapplique la conversion")
    func redoReappliesConversion() {
        let fixture = makeBlock("# ")
        let undoManager = UndoManager()

        fixture.controller.handleMarkdownAutoformat(
            in: fixture.block, typedText: RichText(plainText: "# "), caretOffset: 2, undoManager: undoManager
        )
        undoManager.undo()
        undoManager.redo()

        #expect(fixture.block.type == .heading1)
        #expect(fixture.block.text?.plainText.isEmpty == true)
    }

    @Test("Annuler une conversion inline restaure le texte avec ses delimiteurs")
    func undoRestoresInlineDelimiters() {
        let fixture = makeBlock("**gras**")
        let undoManager = UndoManager()

        fixture.controller.handleMarkdownAutoformat(
            in: fixture.block, typedText: RichText(plainText: "**gras**"), caretOffset: 8, undoManager: undoManager
        )
        #expect(fixture.block.text?.plainText == "gras")

        undoManager.undo()

        #expect(fixture.block.text?.plainText == "**gras**")
    }

    @Test("Annuler un separateur retire le paragraphe insere ET restaure le bloc d'origine")
    func undoDividerRemovesInsertedParagraph() {
        let fixture = makeBlock("---")
        let undoManager = UndoManager()

        fixture.controller.handleMarkdownReturnTrigger(in: fixture.block, undoManager: undoManager)
        #expect(BlockOrdering.topLevelBlocks(of: fixture.note).count == 2)

        undoManager.undo()

        #expect(fixture.block.type == .paragraph)
        #expect(fixture.block.text?.plainText == "---")
        #expect(BlockOrdering.topLevelBlocks(of: fixture.note).count == 1)
    }

    @Test("Retablir un separateur recree un paragraphe suivant")
    func redoDividerRecreatesTrailingParagraph() {
        let fixture = makeBlock("---")
        let undoManager = UndoManager()

        fixture.controller.handleMarkdownReturnTrigger(in: fixture.block, undoManager: undoManager)
        undoManager.undo()
        undoManager.redo()

        #expect(fixture.block.type == .divider)
        #expect(BlockOrdering.topLevelBlocks(of: fixture.note).count == 2)
    }

    /// Meme risque que `EditorControllerDeletionPurgeTests`/
    /// `EditorControllerMarkdownPasteTests.undoingPasteReallyRemovesInsertedBlocksFromContext` :
    /// `BlockOrdering.remove(_:)` ne fait que DETACHER le paragraphe suivant, jamais le
    /// supprimer du `ModelContext` -- un test sur `note.blocks` seul (comme
    /// `undoDividerRemovesInsertedParagraph` ci-dessus) ne le detecterait pas.
    @Test("Annuler un separateur retire vraiment le paragraphe insere du store")
    func undoingDividerReallyRemovesTrailingParagraphFromContext() throws {
        let container = try SlateContainer.make(inMemory: true)
        let context = ModelContext(container)
        let note = Note(title: "Test")
        context.insert(note)
        let block = Block(order: 0, type: .paragraph, text: RichText(plainText: "---"))
        block.note = note
        context.insert(block)
        note.blocks = [block]
        try context.save()

        let controller = EditorController(note: note, modelContext: context)
        let undoManager = UndoManager()
        controller.handleMarkdownReturnTrigger(in: block, undoManager: undoManager)
        try context.save()
        #expect(try context.fetch(FetchDescriptor<Block>()).count == 2)

        undoManager.undo()
        try context.save()

        let remaining = try context.fetch(FetchDescriptor<Block>())
        #expect(remaining.count == 1)
        #expect(remaining[0].id == block.id)
    }
}
