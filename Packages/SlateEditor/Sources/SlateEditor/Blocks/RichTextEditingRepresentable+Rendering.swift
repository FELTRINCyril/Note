import AppKit
import os
import SlateModel
import SlateServices
import SlateUI

/// Pont modele -> vue de `RichTextEditingRepresentable.Coordinator` (`apply(_:to:)`,
/// coloration syntaxique d'un bloc code, sauvegarde) -- extrait de
/// `RichTextEditingRepresentable.swift` pour rester sous la limite de longueur de
/// fichier de `CLAUDE.md` §5 (Phase 8, docs/08_blocs_speciaux.md). Meme type, pas de
/// nouvelle surface publique : `Coordinator` reste `internal`, jamais expose hors de ce
/// module.
extension RichTextEditingRepresentable.Coordinator {
    /// Logger dedie a ce pont AppKit <-> `AttributedString` (voir `apply(_:to:)` et
    /// `textDidChange(_:)`, dans `RichTextEditingRepresentable.swift`) : les deux SEULS
    /// points de ce fichier qui traversent la frontiere `NSAttributedString`, donc les
    /// deux SEULS ou une perte silencieuse d'attribut custom pourrait se reproduire si
    /// le scope explicite etait oublie un jour.
    static var logger: Logger { Logger(subsystem: "com.gemaddis.slate.SlateEditor", category: "RichTextBridging") }

    /// Colore `displayString` selon les tokens produits par `SyntaxHighlighter`
    /// (`SlateServices`) : chaque `SyntaxTokenRole` se resout en couleur via
    /// `SlateSyntaxToken` (`SlateUI`, meme `rawValue` -- verrouille par
    /// `SyntaxHighlightingCorrespondenceTests`). Les tokens de role `plain` sont deja
    /// omis par `SyntaxHighlighter.tokens(for:language:)` (voir sa documentation), rien a
    /// faire pour eux : le texte garde la couleur de base
    /// (`RichTextDisplayAttributes`/`SlateColor.textPrimary`).
    static func applySyntaxHighlighting(
        to displayString: NSMutableAttributedString, plainText: String, language: SyntaxLanguage
    ) {
        guard language != .plainText, !plainText.isEmpty else { return }
        let tokens = SyntaxHighlighter.tokens(for: plainText, language: language)
        for token in tokens {
            guard let role = SlateSyntaxToken(rawValue: token.role.rawValue) else { continue }
            let nsRange = NSRange(token.range, in: plainText)
            guard nsRange.location != NSNotFound, NSMaxRange(nsRange) <= displayString.length else { continue }
            displayString.addAttribute(.foregroundColor, value: NSColor(role.color), range: nsRange)
        }
    }

    func apply(_ text: RichText, to textView: NSTextView) {
        // Pont AttributedString -> NSAttributedString AVEC le scope explicite
        // (symmetrique de `textDidChange(_:)`, meme raison, meme risque de perte
        // silencieuse sans `including:`). Throwing : geree explicitement. Si la
        // conversion echoue, on NE POUSSE RIEN dans le `NSTextView` -- le contenu
        // affiche reste celui d'avant plutot qu'une version amputee.
        let bridged: NSAttributedString
        do {
            bridged = try NSAttributedString(text.attributedString, including: AttributeScopes.SlateAttributes.self)
        } catch {
            Self.logger.error("Pont AttributedString -> NSAttributedString echoue, contenu NON repousse : \(error)")
            return
        }

        // Rendu des marques (Phase 7) : `bridged` porte les attributs Slate/Foundation
        // comme des cles CUSTOM, sans effet visuel propre pour TextKit -- voir la
        // documentation de tete de `RichTextDisplayAttributes`. Cette traduction AJOUTE
        // des attributs de rendu reels sans jamais retirer les cles Slate, donc sans
        // risque pour le prochain `textDidChange(_:)` (qui ne relit que le scope
        // `AttributeScopes.SlateAttributes`, voir sa documentation).
        let displayString = NSMutableAttributedString(attributedString: bridged)
        let baseFont = textView.font ?? NSFont.systemFont(ofSize: SlateFont.body.size)
        RichTextDisplayAttributes.apply(to: displayString, from: text, baseFont: baseFont)

        // Coloration syntaxique (Phase 8, docs/08_blocs_speciaux.md, "Bloc de code") :
        // recalculee a chaque poussee de contenu, jamais mise en cache -- un bloc de
        // code depasse rarement quelques dizaines de lignes, le lexeur maison
        // (`SlateServices.SyntaxHighlighter`) n'a aucun besoin documente d'etre
        // debounce. Applique APRES `RichTextDisplayAttributes.apply` : les marques
        // inline (gras, lien...) n'ont pas de sens sur du code, aucun conflit d'ordre a
        // arbitrer.
        if block.type == .code {
            let language = SyntaxLanguage.resolve(block.attributes.language)
            Self.applySyntaxHighlighting(to: displayString, plainText: text.plainText, language: language)
        }

        // Case a cocher barree/estompee (Phase 8, docs/08 : "texte barre et estompe
        // quand cochee") : applique au contenu ENTIER, en plus de `typingAttributes`
        // (qui ne couvre que les caracteres futurs -- voir `applyTypography(for:
        // isChecked:)`). Ecrase volontairement la couleur des marques inline existantes
        // sur la plage : un item coche est visuellement "termine" dans son ensemble,
        // pas seulement son texte non marque.
        if block.type == .todo, block.attributes.isChecked {
            let fullRange = NSRange(location: 0, length: displayString.length)
            displayString.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: fullRange)
            displayString.addAttribute(.foregroundColor, value: NSColor(SlateColor.todoTextDone), range: fullRange)
        }

        // Caret/selection (qualite de saisie -- CLAUDE.md §1) : `setAttributedString`
        // reinitialise sinon la selection a `(0, 0)`, ce qui deplacerait le caret ou
        // effacerait la selection de l'utilisateur a CHAQUE bascule de marque
        // (`EditorController.toggleMark`/`setHighlight`/... passent TOUJOURS par ce
        // chemin, voir `syncModelIfNeeded`) -- capturee avant, restauree apres, bornee a
        // la nouvelle longueur (une marque ne change jamais le nombre de caracteres,
        // mais rester defensif ici ne coute rien).
        let savedSelection = textView.selectedRange()
        isApplyingModelToView = true
        textView.textStorage?.setAttributedString(displayString)
        isApplyingModelToView = false
        let clampedLocation = min(savedSelection.location, displayString.length)
        let clampedLength = min(savedSelection.length, displayString.length - clampedLocation)
        textView.setSelectedRange(NSRange(location: clampedLocation, length: clampedLength))
    }

    /// Markdown natif (Phase 15, docs/15_markdown_natif.md) : tente une conversion de
    /// bloc/formatage inline sur `richText` (le contenu QUI VIENT D'ETRE bridge depuis
    /// `textView`), AVANT que `textDidChange(_:)` n'ecrive normalement dans
    /// `block.text`. `false` sans aucun effet si aucun motif ne s'est declenche --
    /// l'appelant doit alors ecrire `richText` normalement, comme avant cette phase.
    ///
    /// `true` : `EditorController.handleMarkdownAutoformat` a deja entierement mute
    /// `block.text`/`block.type` (et persiste synchroniquement, comme toute operation
    /// structurelle) -- `lastSyncedText` de ce `Coordinator` est volontairement LAISSE a
    /// sa valeur PRECEDENTE (le contenu d'avant cette frappe) : `syncModelIfNeeded`
    /// (prochain `updateNSView`) detecte alors que `block.text` a change "depuis
    /// l'exterieur" et repousse le nouveau contenu (marqueurs retires) dans ce meme
    /// `NSTextView`, pendant que la requete de caret deja programmee
    /// (`EditorController.applyFocus`) repositionne le caret -- exactement le chemin
    /// normal modele -> vue, jamais un second chemin d'ecriture ad hoc.
    func tryApplyMarkdownAutoformat(richText: RichText, textView: NSTextView) -> Bool {
        let caretOffset = RichTextOffset(utf16Offset: textView.selectedRange().location, in: textView.string)
        guard editorController.handleMarkdownAutoformat(
            in: block, typedText: richText, caretOffset: caretOffset, undoManager: textView.undoManager
        ) else {
            return false
        }
        debouncer.schedule { [weak self] in
            self?.persist()
        }
        return true
    }

    /// Cmd+V (Phase 15, docs/15_markdown_natif.md) : adapte l'appel du delegue de cycle
    /// de vie (`RichTextBlockLifecycleDelegate.richTextViewShouldHandleMarkdownPaste`)
    /// vers `EditorController.handleMarkdownPaste`, en lui fournissant `block`. Extrait
    /// de `RichTextEditingRepresentable.swift` pour rester sous la limite de longueur de
    /// fichier de `CLAUDE.md` §5 -- meme motif exact que `tryApplyMarkdownAutoformat`
    /// ci-dessus.
    func richTextViewShouldHandleMarkdownPaste(
        text: String, replacingRange: RichTextRange, undoManager: UndoManager?
    ) -> Bool {
        editorController.handleMarkdownPaste(
            pasteboardText: text, in: block, replacingRange: replacingRange, undoManager: undoManager
        )
    }

    /// Le point de sauvegarde UNIQUE (voir `BlockTextCommit`) : recalcule les champs
    /// derives de la note, horodate la modification, puis ecrit reellement sur disque.
    /// Invoque uniquement au flush du debounce -- jamais a chaque frappe.
    func persist() {
        BlockTextCommit.flush(block: block)
        try? modelContext.save()
    }
}
