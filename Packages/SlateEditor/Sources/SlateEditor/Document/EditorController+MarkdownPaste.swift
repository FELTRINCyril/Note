import Foundation
import SlateModel
import SlateUI

/// Branchement du collage markdown (docs/15_markdown_natif.md, "Coller du markdown ->
/// conversion optionnelle en blocs (reglage)") sur le cycle de vie des blocs -- meme
/// separation que `EditorController+MarkdownShortcuts.swift` (frappe) : detection/
/// decoupage delegues a `MarkdownBlockParser` (pur), application au modele ICI.
///
/// ## Reglage (`EditorPreferences.convertsMarkdownOnPaste`)
/// Lu directement depuis `EditorPreferences.shared` (`SlateUI`) : ce reglage n'a pas de
/// geometrie/rendu propre a l'editeur (contrairement a `ThemeManager`, dont
/// `NoteHeaderView` lit `showsNoteCover` par exemple), donc pas besoin de le faire
/// transiter par l'environnement SwiftUI jusqu'ici -- `RichTextEditingTextView.paste(_:)`
/// (AppKit pur, hors arbre de vues SwiftUI) ne pourrait de toute facon pas lire un
/// `@Environment`.
///
/// ## Annulation en une seule etape (meme raisonnement que la frappe)
/// Un collage converti peut inserer PLUSIEURS blocs supplementaires (un par ligne
/// markdown au-dela de la premiere) en plus de muter le bloc courant : `registerUndo`
/// est appele SYNCHRONEMENT depuis `RichTextEditingTextView.paste(_:)`, dans le meme
/// "event" que Cmd+V -- voir la documentation de tete de
/// `EditorController+MarkdownShortcuts.swift` pour le raisonnement complet sur
/// `UndoManager.groupsByEvent`. L'annulation retire tous les blocs inseres ET restaure
/// le bloc d'origine ; le retablissement rejoue le meme decoupage (deterministe, memes
/// blocs analyses) et re-enregistre sa propre annulation.
extension EditorController {
    /// A appeler par `RichTextEditingTextView.paste(_:)` AVANT le comportement natif
    /// (`super.paste(_:)`, qui gere deja texte brut/RTF/images) : `true` si le collage a
    /// ete entierement pris en charge comme une conversion en blocs, auquel cas
    /// l'appelant NE DOIT PAS appeler `super.paste(_:)` en plus pour ce meme evenement.
    ///
    /// `false` sans AUCUN effet de bord des que l'une des conditions manque -- l'appelant
    /// doit alors laisser le collage natif s'executer exactement comme avant cette
    /// phase (garde-fou explicite de la tache : "si le reglage est desactive, le collage
    /// doit inserer le texte brut exactement comme aujourd'hui").
    @discardableResult
    public func handleMarkdownPaste(
        pasteboardText: String, in block: Block, replacingRange: RichTextRange, undoManager: UndoManager?
    ) -> Bool {
        guard EditorPreferences.shared.convertsMarkdownOnPaste else { return false }
        // Bloc de code (meme regle que la frappe, docs/15) : on colle du markdown
        // LITTERAL dans un bloc `.code`, jamais interprete.
        guard block.type != .code else { return false }
        guard MarkdownBlockParser.containsMarkdownSyntax(pasteboardText) else { return false }
        let parsedBlocks = MarkdownBlockParser.parse(pasteboardText)
        guard !parsedBlocks.isEmpty else { return false }

        let before = captureMarkdownSnapshot(of: block, caret: replacingRange.lowerBound)
        let insertedBlocks = performMarkdownPaste(parsedBlocks, in: block, replacingRange: replacingRange)
        registerMarkdownPasteUndo(
            undoManager, block: block, insertedBlocks: insertedBlocks,
            before: before, parsedBlocks: parsedBlocks, replacingRange: replacingRange
        )
        return true
    }

    /// Materialise `parsedBlocks` a la place de `replacingRange` dans `block` :
    /// - le texte de part et d'autre de `replacingRange` (`head`/`tail`, memes noms que
    ///   `BlockLifecycle.handleEnter`) est preserve, formatage inline inclus ;
    /// - si `head` est VIDE, `block` lui-meme DEVIENT le premier bloc analyse (pas de
    ///   paragraphe vide residuel avant le contenu colle -- le cas le plus courant,
    ///   coller dans un bloc fraichement cree) ; sinon `block` garde son type et son
    ///   texte actuel devient `head`, et TOUS les blocs analyses sont inseres a la suite ;
    /// - `tail` rejoint la fin du DERNIER bloc concerne (celui qui porte le dernier
    ///   `ParsedBlock`), pour que le texte qui suivait le point de collage ne soit
    ///   jamais perdu ni deplace avant le contenu colle.
    ///
    /// Retourne la liste des blocs NOUVELLEMENT CREES (jamais `block` lui-meme) --
    /// exactement ce que l'annulation doit retirer.
    private func performMarkdownPaste(
        _ parsedBlocks: [MarkdownBlockParser.ParsedBlock], in block: Block, replacingRange: RichTextRange
    ) -> [Block] {
        let currentText = block.text ?? RichText()
        let trimmedText = currentText.removingCharacters(in: replacingRange)
        let (head, tail) = trimmedText.split(atCharacterOffset: replacingRange.lowerBound)

        var remaining = parsedBlocks[...]
        if head.isEmpty, let first = remaining.first {
            block.attributes = markdownPasteAttributes(from: block.attributes, parsed: first)
            block.type = first.type
            block.text = first.text
            remaining = remaining.dropFirst()
        } else {
            block.text = head
        }

        var insertedBlocks: [Block] = []
        var anchor = block
        var caretTargetBlock = block
        for parsed in remaining {
            let attributes = markdownPasteAttributes(from: BlockAttributes(), parsed: parsed)
            let newBlock = Block(type: parsed.type, text: parsed.text, attributes: attributes)
            BlockOrdering.insert(newBlock, after: anchor)
            insertedBlocks.append(newBlock)
            anchor = newBlock
            caretTargetBlock = newBlock
        }

        let caretAfterPastedContent = RichTextOffset(characters: caretTargetBlock.text?.plainText.count ?? 0)
        if !tail.isEmpty {
            var targetText = caretTargetBlock.text ?? RichText()
            targetText.attributedString.append(tail.attributedString)
            caretTargetBlock.text = targetText
        }

        persistStructuralChange()
        applyFocus(EditorCaretRequest(blockID: caretTargetBlock.id, placement: .offset(caretAfterPastedContent)))
        return insertedBlocks
    }

    /// `BlockConversion.convertedAttributes(from:to:)` recalcule `headingLevel` a partir
    /// du type d'arrivee (voir sa documentation) ; `isChecked` y est ensuite ECRASE par
    /// celui du `ParsedBlock` -- un `[x] ` colle doit produire une tache cochee, jamais
    /// l'etat coche PRECEDENT du bloc qu'il remplace/rejoint.
    private func markdownPasteAttributes(
        from old: BlockAttributes, parsed: MarkdownBlockParser.ParsedBlock
    ) -> BlockAttributes {
        var attributes = BlockConversion.convertedAttributes(from: old, to: parsed.type)
        attributes.isChecked = parsed.isChecked
        return attributes
    }

    /// Voir la documentation de tete de fichier. Recursif comme `registerDividerUndo`
    /// (`EditorController+MarkdownShortcuts.swift`) : le retablissement rejoue
    /// `performMarkdownPaste` sur les MEMES `parsedBlocks`/`replacingRange` (deterministe)
    /// et re-enregistre sa propre annulation, plutot que de rejouer un enregistrement
    /// fige.
    private func registerMarkdownPasteUndo(
        _ undoManager: UndoManager?,
        block: Block,
        insertedBlocks: [Block],
        before: MarkdownConversionSnapshot,
        parsedBlocks: [MarkdownBlockParser.ParsedBlock],
        replacingRange: RichTextRange
    ) {
        guard let undoManager else { return }
        undoManager.registerUndo(withTarget: self) { controller in
            for inserted in insertedBlocks {
                BlockOrdering.remove(inserted)
                // `BlockOrdering.remove(_:)` ne fait que DETACHER (voir sa
                // documentation) : sans ce `delete(_:)`, chaque annulation d'un collage
                // markdown laisserait les blocs inseres orphelins dans le `ModelContext`
                // -- persistes indefiniment et synchronises vers CloudKit tout en etant
                // invisibles dans l'interface. Meme garantie que `EditorController.
                // deleteBlock(_:)` (voir `EditorControllerDeletionPurgeTests`).
                controller.modelContext?.delete(inserted)
            }
            controller.restoreMarkdownSnapshot(before, to: block)
            undoManager.registerUndo(withTarget: controller) { redoController in
                let newlyInserted = redoController.performMarkdownPaste(
                    parsedBlocks, in: block, replacingRange: replacingRange
                )
                redoController.registerMarkdownPasteUndo(
                    undoManager, block: block, insertedBlocks: newlyInserted,
                    before: before, parsedBlocks: parsedBlocks, replacingRange: replacingRange
                )
            }
        }
    }
}
