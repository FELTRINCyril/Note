import Foundation
import SlateModel
import SlateUI
import SwiftData
import Testing

@testable import SlateEditor

/// `EditorController.handleMarkdownPaste` (docs/15_markdown_natif.md, "Coller du
/// markdown -> conversion optionnelle en blocs"). Meme regle que le reste de la suite :
/// aucun `NSTextView`, uniquement une `Note`/`Block` en memoire et un `UndoManager`
/// Foundation nu pour l'annulation.
///
/// `EditorPreferences.shared` est un singleton PARTAGE entre tests : chaque test
/// restaure explicitement sa valeur d'origine en fin d'execution (`defer`), pour ne
/// jamais laisser un test affecter l'ordre d'execution d'un autre (Swift Testing ne
/// garantit aucun ordre).
@MainActor
@Suite("EditorController.MarkdownPaste")
struct EditorControllerMarkdownPasteTests {
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

    private func caret(_ offset: Int) -> RichTextRange {
        RichTextRange(caret: RichTextOffset(characters: offset))
    }

    private func withMarkdownPasteEnabled(_ enabled: Bool, _ body: () throws -> Void) rethrows {
        let original = EditorPreferences.shared.convertsMarkdownOnPaste
        EditorPreferences.shared.convertsMarkdownOnPaste = enabled
        defer { EditorPreferences.shared.convertsMarkdownOnPaste = original }
        try body()
    }

    // MARK: - Collage dans un bloc VIDE : le bloc devient le premier bloc analyse

    @Test("Coller du markdown multi-lignes dans un bloc vide cree tous les blocs, dans l'ordre")
    func pastingIntoEmptyBlockCreatesAllParsedBlocks() {
        withMarkdownPasteEnabled(true) {
            let fixture = makeBlock("")

            let handled = fixture.controller.handleMarkdownPaste(
                pasteboardText: "# Titre\n- Un\n- Deux", in: fixture.block, replacingRange: caret(0), undoManager: nil
            )

            #expect(handled)
            let blocks = BlockOrdering.topLevelBlocks(of: fixture.note)
            #expect(blocks.count == 3)
            #expect(blocks[0].id == fixture.block.id)
            #expect(blocks[0].type == .heading1)
            #expect(blocks[1].type == .bulletedList)
            #expect(blocks[1].text?.plainText == "Un")
            #expect(blocks[2].text?.plainText == "Deux")
        }
    }

    @Test("Coller un bloc de code multi-lignes dans un bloc vide produit un seul bloc code")
    func pastingFencedCodeIntoEmptyBlockProducesOneCodeBlock() {
        withMarkdownPasteEnabled(true) {
            let fixture = makeBlock("")

            fixture.controller.handleMarkdownPaste(
                pasteboardText: "```\nlet x = 1\nlet y = 2\n```",
                in: fixture.block,
                replacingRange: caret(0),
                undoManager: nil
            )

            let blocks = BlockOrdering.topLevelBlocks(of: fixture.note)
            #expect(blocks.count == 1)
            #expect(blocks[0].type == .code)
            #expect(blocks[0].text?.plainText == "let x = 1\nlet y = 2")
        }
    }

    // MARK: - Collage au milieu d'un bloc NON VIDE : head/tail preserves

    @Test("Coller au milieu d'un bloc non vide garde le bloc courant intact (head) et rattache la fin au bloc insere")
    func pastingInsideNonEmptyBlockKeepsCurrentBlockAsHead() {
        withMarkdownPasteEnabled(true) {
            let fixture = makeBlock("Avant FIN")
            // Caret juste apres "Avant " (6 caracteres), avant "FIN".
            let handled = fixture.controller.handleMarkdownPaste(
                pasteboardText: "# Titre", in: fixture.block, replacingRange: caret(6), undoManager: nil
            )

            #expect(handled)
            let blocks = BlockOrdering.topLevelBlocks(of: fixture.note)
            #expect(blocks.count == 2)
            // `head` ("Avant ") N'EST PAS VIDE : le bloc courant garde son type ET son
            // texte de tete, inchanges -- le contenu colle rejoint un NOUVEAU bloc.
            #expect(blocks[0].id == fixture.block.id)
            #expect(blocks[0].type == .paragraph)
            #expect(blocks[0].text?.plainText == "Avant ")
            #expect(blocks[1].type == .heading1)
            // "FIN" (le texte apres le point de collage) rejoint la fin du bloc insere.
            #expect(blocks[1].text?.plainText == "TitreFIN")
        }
    }

    @Test("Coller plusieurs blocs au milieu d'un texte insere les nouveaux blocs et rattache la fin a la suite")
    func pastingMultipleBlocksInsideTextInsertsSiblingsAndReattachesTail() {
        withMarkdownPasteEnabled(true) {
            let fixture = makeBlock("Avant FIN")
            let handled = fixture.controller.handleMarkdownPaste(
                pasteboardText: "- Un\n- Deux", in: fixture.block, replacingRange: caret(6), undoManager: nil
            )

            #expect(handled)
            let blocks = BlockOrdering.topLevelBlocks(of: fixture.note)
            #expect(blocks.count == 3)
            #expect(blocks[0].id == fixture.block.id)
            #expect(blocks[0].type == .paragraph)
            #expect(blocks[0].text?.plainText == "Avant ")
            #expect(blocks[1].type == .bulletedList)
            #expect(blocks[1].text?.plainText == "Un")
            #expect(blocks[2].type == .bulletedList)
            // "FIN" (le texte apres le point de collage) rejoint la fin du DERNIER bloc.
            #expect(blocks[2].text?.plainText == "DeuxFIN")
        }
    }

    // MARK: - Garde-fous : reglage desactive, bloc de code, texte sans markdown

    @Test("Reglage desactive : le collage n'est jamais pris en charge, aucun effet")
    func disabledSettingNeverHandlesPaste() {
        withMarkdownPasteEnabled(false) {
            let fixture = makeBlock("")

            let handled = fixture.controller.handleMarkdownPaste(
                pasteboardText: "# Titre", in: fixture.block, replacingRange: caret(0), undoManager: nil
            )

            #expect(handled == false)
            #expect(fixture.block.type == .paragraph)
            #expect(fixture.block.text?.plainText.isEmpty == true)
        }
    }

    @Test("Bloc de code : coller du markdown n'est jamais interprete a l'interieur")
    func codeBlockNeverInterpretsPastedMarkdown() {
        withMarkdownPasteEnabled(true) {
            let fixture = makeBlock("", type: .code)

            let handled = fixture.controller.handleMarkdownPaste(
                pasteboardText: "# Titre", in: fixture.block, replacingRange: caret(0), undoManager: nil
            )

            #expect(handled == false)
            #expect(fixture.block.type == .code)
        }
    }

    @Test("Texte sans motif markdown : jamais pris en charge, le collage natif doit s'executer")
    func plainTextIsNeverHandled() {
        withMarkdownPasteEnabled(true) {
            let fixture = makeBlock("")

            let handled = fixture.controller.handleMarkdownPaste(
                pasteboardText: "Un texte tout a fait ordinaire.",
                in: fixture.block,
                replacingRange: caret(0),
                undoManager: nil
            )

            #expect(handled == false)
        }
    }

    // MARK: - Annulation en une seule etape

    @Test("Annuler un collage multi-blocs retire tous les blocs inseres et restaure le bloc d'origine")
    func undoRemovesAllInsertedBlocksAndRestoresOriginal() {
        withMarkdownPasteEnabled(true) {
            let fixture = makeBlock("")
            let undoManager = UndoManager()

            fixture.controller.handleMarkdownPaste(
                pasteboardText: "# Titre\n- Un\n- Deux",
                in: fixture.block,
                replacingRange: caret(0),
                undoManager: undoManager
            )
            #expect(BlockOrdering.topLevelBlocks(of: fixture.note).count == 3)

            undoManager.undo()

            let blocks = BlockOrdering.topLevelBlocks(of: fixture.note)
            #expect(blocks.count == 1)
            #expect(blocks[0].id == fixture.block.id)
            #expect(blocks[0].type == .paragraph)
            #expect(blocks[0].text?.plainText.isEmpty == true)
        }
    }

    @Test("Retablir un collage annule recree les memes blocs")
    func redoRecreatesTheSameBlocks() {
        withMarkdownPasteEnabled(true) {
            let fixture = makeBlock("")
            let undoManager = UndoManager()

            fixture.controller.handleMarkdownPaste(
                pasteboardText: "# Titre\n- Un\n- Deux",
                in: fixture.block,
                replacingRange: caret(0),
                undoManager: undoManager
            )
            undoManager.undo()
            undoManager.redo()

            let blocks = BlockOrdering.topLevelBlocks(of: fixture.note)
            #expect(blocks.count == 3)
            #expect(blocks[0].type == .heading1)
            #expect(blocks[1].text?.plainText == "Un")
            #expect(blocks[2].text?.plainText == "Deux")
        }
    }

    // MARK: - Purge reelle du store a l'annulation (voir `EditorControllerDeletionPurgeTests`)

    /// Meme risque que celui documente/corrige par `EditorControllerDeletionPurgeTests` :
    /// `BlockOrdering.remove(_:)` ne fait que DETACHER, jamais supprimer du
    /// `ModelContext`. Un test qui se contenterait de lire `note.blocks` (comme les deux
    /// tests d'annulation ci-dessus) ne verrait RIEN de cette classe de bug, puisque le
    /// detachement, lui, fonctionne deja correctement -- il faut un vrai `ModelContext`
    /// et interroger le store directement (`FetchDescriptor<Block>()`).
    @Test("Annuler un collage multi-blocs retire vraiment les blocs inseres du store")
    func undoingPasteReallyRemovesInsertedBlocksFromContext() throws {
        try withMarkdownPasteEnabled(true) {
            let container = try SlateContainer.make(inMemory: true)
            let context = ModelContext(container)
            let note = Note(title: "Test")
            context.insert(note)
            let block = Block(order: 0, type: .paragraph, text: RichText(plainText: ""))
            block.note = note
            context.insert(block)
            note.blocks = [block]
            try context.save()

            let controller = EditorController(note: note, modelContext: context)
            let undoManager = UndoManager()
            controller.handleMarkdownPaste(
                pasteboardText: "# Titre\n- Un\n- Deux",
                in: block,
                replacingRange: caret(0),
                undoManager: undoManager
            )
            try context.save()
            #expect(try context.fetch(FetchDescriptor<Block>()).count == 3)

            undoManager.undo()
            try context.save()

            let remaining = try context.fetch(FetchDescriptor<Block>())
            #expect(remaining.count == 1)
            #expect(remaining[0].id == block.id)
        }
    }
}
