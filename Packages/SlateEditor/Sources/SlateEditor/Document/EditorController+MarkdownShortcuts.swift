import Foundation
import SlateModel

/// Branchement du markdown natif a la frappe (docs/15_markdown_natif.md) sur le cycle
/// de vie des blocs : detection deleguee a `MarkdownShortcutEngine` (pure), application
/// au modele ICI -- meme separation exacte que le reste de `EditorController`
/// (`BlockLifecycle`/`BlockOrdering` pour le cycle de vie, `FormattingEngine` pour le
/// formatage inline classique).
///
/// ## Annulation en une seule etape (le point dur de la Phase 15)
/// Une conversion markdown mute DEUX choses en une frappe : le TEXTE du bloc (retrait
/// des marqueurs) et son TYPE (`BlockType`)/ses `BlockAttributes`. Le texte tape juste
/// avant (le marqueur lui-meme, ex. l'espace de `"# "`) est deja pris en charge par
/// l'`NSUndoManager` PROPRE au `NSTextView` (`allowsUndo = true`,
/// `RichTextEditingTextView`) -- AUTOMATIQUEMENT, sans rien coder ici : c'est le
/// `NSTextView` natif qui l'enregistre au moment ou il insere le caractere, AVANT que
/// `textDidChange`/ce fichier ne s'executent.
///
/// Le risque documente par la tache : si la conversion de type ne rejoint pas CE MEME
/// pas d'annulation, Cmd+Z ne defait que la moitie "texte" (ou rien du tout, le texte
/// du `NSTextView` etant deja passe sous le controle du modele) et laisse le document
/// dans un etat incoherent (type de bloc et contenu textuel desynchronises).
///
/// Solution retenue : `UndoManager.registerUndo(withTarget:handler:)`, appele
/// SYNCHRONEMENT depuis `textDidChange`/`insertNewline` -- donc dans le MEME "event" de
/// run loop que la frappe qui a declenche la conversion. `UndoManager.groupsByEvent`
/// (valeur par defaut de Foundation, jamais desactivee nulle part dans ce module --
/// verifie par recherche texte) regroupe AUTOMATIQUEMENT toutes les actions
/// d'annulation enregistrees pendant un meme "event" en un seul groupe : la frappe de
/// l'espace (enregistree par le `NSTextView` natif) et notre restauration du
/// texte+type (enregistree ici, dans le meme tour de boucle) se defont donc TOUJOURS
/// ensemble, en une seule pression de Cmd+Z. Chaque `register*Undo` ci-dessous
/// re-enregistre en plus symmetriquement son INVERSE lors de son execution, pour que le
/// retablissement (Cmd+Maj+Z) fonctionne exactement pareil dans l'autre sens.
///
/// `UndoManager` est un type Foundation ordinaire (pas AppKit) : cette extension reste
/// testable HORS AppKit/fenetre, exactement comme le reste de `EditorController` --
/// un test construit un `UndoManager()` nu, appelle une methode, puis `.undo()`.
///
/// ## Ce que cette couche NE fait PAS
/// Ni `RichTextEditingTextView` ni `RichTextEditingRepresentable.Coordinator` ne
/// decident jamais eux-memes QUEL motif markdown s'applique : ils fournissent
/// uniquement le texte/caret courants (deja bridges en `RichText`/`RichTextOffset`,
/// meme frontiere que le reste du fichier) et leur `NSTextView.undoManager`.
extension EditorController {
    // MARK: - Point d'entree : frappe d'un caractere (espace ou delimiteur inline)

    /// A appeler par `RichTextEditingRepresentable.Coordinator.textDidChange(_:)` AVANT
    /// d'ecrire `typedText` dans `block.text` normalement : si cette methode retourne
    /// `true`, elle a deja entierement pris en charge la mutation du modele (texte ET
    /// type), l'appelant ne doit RIEN ecrire de plus pour cette frappe.
    ///
    /// `typedText` : le contenu du bloc TEL QUE VIENT DE LE PRODUIRE la frappe (deja
    /// bridge en `RichText`, formatage inline existant inclus). `caretOffset` : position
    /// du caret immediatement apres cette frappe -- le caractere qui vient d'etre tape
    /// est donc, par construction, celui juste avant le caret (meme convention que
    /// `EditorController.updateSlashMenuState`).
    @discardableResult
    public func handleMarkdownAutoformat(
        in block: Block, typedText: RichText, caretOffset: RichTextOffset, undoManager: UndoManager?
    ) -> Bool {
        // Le menu "/" est prioritaire et n'a de toute facon aucun recouvrement de
        // caracteres avec les motifs markdown (voir la documentation de tete de
        // `EditorController+SlashMenu.swift`) -- garde defensive explicite plutot que de
        // s'appuyer implicitement sur cette absence de recouvrement.
        guard slashMenuState?.blockID != block.id else { return false }

        let plainText = typedText.plainText
        let characters = Array(plainText)
        let caret = caretOffset.characters
        guard caret > 0, caret <= characters.count else { return false }
        let justTyped = characters[caret - 1]

        if justTyped == " ", block.type == .paragraph,
           let trigger = MarkdownShortcutEngine.blockSpaceTrigger(text: plainText, caret: caret) {
            applyBlockSpaceTrigger(trigger, in: block, typedText: typedText, undoManager: undoManager)
            return true
        }

        // Bloc de code (docs/15, conflit "code inline/bloc de code ne convertissent
        // jamais de markdown a l'interieur") : on tape du markdown LITTERAL dans un
        // bloc `.code`, jamais interprete.
        guard block.type != .code,
              let trigger = MarkdownShortcutEngine.inlineTrigger(justTyped: justTyped, text: plainText, caret: caret)
        else {
            return false
        }
        applyInlineTrigger(trigger, in: block, typedText: typedText, undoManager: undoManager)
        return true
    }

    // MARK: - Point d'entree : Entree (motifs sans espace, docs/15)

    /// A appeler par `RichTextEditingTextView.insertNewline(_:)` (via le delegue de
    /// cycle de vie), AVANT `handleEnter(in:caretOffset:)` : `true` si un motif
    /// `` ``` ``/`---` a pris la main, auquel cas l'appelant ne doit PAS executer le
    /// split de bloc normal pour cette pression d'Entree.
    @discardableResult
    public func handleMarkdownReturnTrigger(in block: Block, undoManager: UndoManager?) -> Bool {
        guard block.type == .paragraph, slashMenuState?.blockID != block.id else { return false }
        guard let trigger = MarkdownShortcutEngine.blockReturnTrigger(text: block.text?.plainText ?? "") else {
            return false
        }
        switch trigger {
        case .codeBlock:
            applyCodeBlockReturnTrigger(in: block, undoManager: undoManager)
        case .divider:
            applyDividerReturnTrigger(in: block, undoManager: undoManager)
        }
        return true
    }

    // MARK: - Application : declencheurs de bloc a l'espace

    private func applyBlockSpaceTrigger(
        _ trigger: MarkdownShortcutEngine.BlockSpaceTrigger,
        in block: Block,
        typedText: RichText,
        undoManager: UndoManager?
    ) {
        let before = captureMarkdownSnapshot(of: block, caret: RichTextOffset(characters: trigger.markerLength))
        let trimmed = typedText.removingCharacters(
            in: RichTextRange(lowerBound: 0, upperBound: RichTextOffset(characters: trigger.markerLength))
        )
        performInPlaceMarkdownConversion(
            in: block, resultingText: trimmed, targetType: trigger.targetType, checkedOverride: trigger.checkedOverride
        )
        let after = captureMarkdownSnapshot(of: block, caret: 0)
        registerSimpleMarkdownUndo(undoManager, block: block, before: before, after: after)
    }

    // MARK: - Application : declencheurs de bloc a l'Entree

    private func applyCodeBlockReturnTrigger(in block: Block, undoManager: UndoManager?) {
        let currentLength = (block.text?.plainText ?? "").count
        let before = captureMarkdownSnapshot(of: block, caret: RichTextOffset(characters: currentLength))
        performInPlaceMarkdownConversion(
            in: block, resultingText: RichText(), targetType: .code, checkedOverride: .unspecified
        )
        let after = captureMarkdownSnapshot(of: block, caret: 0)
        registerSimpleMarkdownUndo(undoManager, block: block, before: before, after: after)
    }

    /// `.divider` (docs/15) : memes contraintes que `EditorController+SlashMenu.swift`,
    /// `executeDividerCommand` -- `.divider` ne porte pas de `RichText` propre et ne
    /// peut pas accueillir le caret, un paragraphe VIDE est donc TOUJOURS insere apres
    /// lui et focalise. Contrairement au menu "/", ce second bloc fait partie
    /// INTEGRANTE de l'annulation d'une seule frappe : `registerDividerUndo` le retire a
    /// l'annulation et le recree (un nouvel objet, jamais le meme, sans consequence
    /// observable) au retablissement.
    private func applyDividerReturnTrigger(in block: Block, undoManager: UndoManager?) {
        let currentLength = (block.text?.plainText ?? "").count
        let before = captureMarkdownSnapshot(of: block, caret: RichTextOffset(characters: currentLength))
        let trailingParagraph = performDividerConversion(in: block)
        registerDividerUndo(undoManager, block: block, trailingParagraph: trailingParagraph, before: before)
    }

    private func performDividerConversion(in block: Block) -> Block {
        block.attributes = BlockConversion.convertedAttributes(from: block.attributes, to: .divider)
        block.type = .divider
        let trailingParagraph = Block(type: .paragraph, text: RichText())
        BlockOrdering.insert(trailingParagraph, after: block)
        persistStructuralChange()
        applyFocus(EditorCaretRequest(blockID: trailingParagraph.id, placement: .offset(0)))
        return trailingParagraph
    }

    // MARK: - Application : formatage inline au delimiteur fermant

    private func applyInlineTrigger(
        _ trigger: MarkdownShortcutEngine.InlineTrigger,
        in block: Block,
        typedText: RichText,
        undoManager: UndoManager?
    ) {
        let beforeCaret = RichTextOffset(characters: trigger.contentRange.upperBound + trigger.closeDelimiterLength)
        let before = MarkdownConversionSnapshot(
            type: block.type, attributes: block.attributes, text: typedText, caret: beforeCaret
        )

        // `MarkdownShortcutEngine.consuming(_:in:)` : logique de consommation PARTAGEE
        // avec le collage (`MarkdownBlockParser`/`EditorController+MarkdownPaste.swift`).
        let text = MarkdownShortcutEngine.consuming(trigger, in: typedText)
        block.text = text
        persistStructuralChange()

        let newCaret = RichTextOffset(characters: trigger.contentRange.upperBound - trigger.openDelimiterLength)
        applyFocus(EditorCaretRequest(blockID: block.id, placement: .offset(newCaret)))

        let after = MarkdownConversionSnapshot(
            type: block.type, attributes: block.attributes, text: text, caret: newCaret
        )
        registerSimpleMarkdownUndo(undoManager, block: block, before: before, after: after)
    }

    // MARK: - Mutation commune aux conversions EN PLACE (pas de bloc supplementaire)

    private func performInPlaceMarkdownConversion(
        in block: Block,
        resultingText: RichText,
        targetType: BlockType,
        checkedOverride: MarkdownShortcutEngine.CheckedOverride
    ) {
        block.text = resultingText
        BlockConversion.convert(block, to: targetType)
        if case let .forced(isChecked) = checkedOverride {
            block.attributes.isChecked = isChecked
        }
        persistStructuralChange()
        applyFocus(EditorCaretRequest(blockID: block.id, placement: .offset(0)))
    }

    // MARK: - Annulation : instantanes et enregistrement symmetrique

    // Pas `private` (contrairement au reste de ce fichier) : `EditorController+MarkdownPaste.swift`
    // (le collage, meme phase) reutilise ces deux instantanes plutot que de les
    // dupliquer -- meme motif que `persistStructuralChange()`/`applyFocus(_:)` dans
    // `EditorController.swift`.
    func captureMarkdownSnapshot(of block: Block, caret: RichTextOffset) -> MarkdownConversionSnapshot {
        MarkdownConversionSnapshot(
            type: block.type, attributes: block.attributes, text: block.text ?? RichText(), caret: caret
        )
    }

    func restoreMarkdownSnapshot(_ snapshot: MarkdownConversionSnapshot, to block: Block) {
        block.type = snapshot.type
        block.attributes = snapshot.attributes
        block.text = snapshot.text
        persistStructuralChange()
        applyFocus(EditorCaretRequest(blockID: block.id, placement: .offset(snapshot.caret)))
    }

    /// Voir la documentation de tete de fichier : enregistre `before` comme action
    /// d'annulation, et RE-enregistre `after` comme action de retablissement des que
    /// l'annulation s'execute -- symmetrique dans les deux sens, applicable a toute
    /// conversion EN PLACE (declencheurs de bloc a l'espace, code par Entree, formatage
    /// inline : aucun de ces trois ne cree de bloc supplementaire, contrairement au
    /// separateur -- voir `registerDividerUndo`).
    private func registerSimpleMarkdownUndo(
        _ undoManager: UndoManager?, block: Block, before: MarkdownConversionSnapshot, after: MarkdownConversionSnapshot
    ) {
        guard let undoManager else { return }
        undoManager.registerUndo(withTarget: self) { controller in
            controller.restoreMarkdownSnapshot(before, to: block)
            controller.registerSimpleMarkdownUndo(undoManager, block: block, before: after, after: before)
        }
    }

    /// Symmetrique de `registerSimpleMarkdownUndo` pour le separateur (docs/15) : en
    /// plus de restaurer `block`, retire le paragraphe suivant cree par la conversion
    /// -- et le recree (nouvel objet) si l'utilisateur retablit ensuite (Cmd+Maj+Z).
    private func registerDividerUndo(
        _ undoManager: UndoManager?, block: Block, trailingParagraph: Block, before: MarkdownConversionSnapshot
    ) {
        guard let undoManager else { return }
        undoManager.registerUndo(withTarget: self) { controller in
            BlockOrdering.remove(trailingParagraph)
            // Meme purge que `registerMarkdownPasteUndo` (`EditorController+MarkdownPaste.swift`)
            // et `EditorController.deleteBlock(_:)` : `BlockOrdering.remove(_:)` ne fait
            // que detacher, jamais supprimer du store.
            controller.modelContext?.delete(trailingParagraph)
            controller.restoreMarkdownSnapshot(before, to: block)
            undoManager.registerUndo(withTarget: controller) { redoController in
                let newTrailingParagraph = redoController.performDividerConversion(in: block)
                redoController.registerDividerUndo(
                    undoManager, block: block, trailingParagraph: newTrailingParagraph, before: before
                )
            }
        }
    }
}

/// Instantane du strict necessaire pour annuler/retablir une conversion markdown (frappe
/// OU collage) : type, attributs, texte ET position de caret d'AVANT ou d'APRES la
/// conversion -- voir la documentation de tete de fichier. Pas `private` : partage avec
/// `EditorController+MarkdownPaste.swift`.
struct MarkdownConversionSnapshot {
    let type: BlockType
    let attributes: BlockAttributes
    let text: RichText
    let caret: RichTextOffset
}
