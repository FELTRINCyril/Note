import AppKit
import SlateModel

/// Raccourcis de formatage et geometrie de la selection (docs/07_typographie_formatage.md)
/// -- extrait de `RichTextEditingTextView.swift` pour rester sous la limite de longueur
/// de fichier de `CLAUDE.md` §5. `handleFormattingKeyEquivalent(_:)` reste appelee
/// depuis l'override `performKeyEquivalent(with:)` (qui, lui, DOIT rester dans le
/// fichier principal -- Swift interdit `override` dans une extension).
extension RichTextEditingTextView {
    // MARK: - Raccourcis clavier (docs/07_typographie_formatage.md)
    //
    // `performKeyEquivalent(with:)` est le point d'accroche recommande pour des
    // combinaisons Cmd (voir la tache) : contrairement a `insertNewline(_:)`/
    // `deleteBackward(_:)` (des ACTIONS `NSResponder` que `NSTextView` appelle deja),
    // Cmd+B/I/U/E/K et Cmd+Opt+0..3 ne correspondent a AUCUN selecteur natif que
    // `NSTextView` invoquerait de lui-meme -- il faut intercepter l'evenement clavier
    // brut avant qu'AppKit ne le laisse tomber silencieusement (aucun Format-menu n'est
    // cable dans ce projet, voir CLAUDE.md -- perimetre de l'agent editeur, pas de la
    // barre de menus).

    func handleFormattingKeyEquivalent(_ event: NSEvent) -> Bool {
        guard event.type == .keyDown, let delegate = blockLifecycleDelegate else { return false }
        guard let characters = event.charactersIgnoringModifiers?.lowercased() else { return false }
        let flags = event.modifierFlags.intersection([.command, .shift, .option, .control])
        let selection = RichTextRange(utf16Range: selectedRange(), in: string)

        // Chaque delegue de marque/conversion retourne TOUJOURS `true` (voir la
        // documentation de `RichTextBlockLifecycleDelegate`, section "Raccourcis de
        // formatage") : `false` ne peut donc signifier ICI que "ce n'est pas notre
        // combinaison", jamais "geree mais refusee" -- un simple `Bool` (jamais
        // `Bool?`, `discouraged_optional_boolean` de `CLAUDE.md` §5) suffit donc a
        // enchainer les deux listes sans ambiguite.
        if Self.markShortcut(flags: flags, characters: characters, selection: selection, delegate: delegate) {
            return true
        }
        return Self.conversionShortcut(flags: flags, characters: characters, delegate: delegate)
    }

    /// Raccourcis de MARQUE (gras/italique/souligne/barre/code/lien) -- `false` si
    /// `(flags, characters)` ne correspond a aucun d'entre eux (laisse
    /// `conversionShortcut(flags:characters:delegate:)` tenter sa propre liste), separe
    /// de celui-ci pour rester sous le seuil de complexite cyclomatique de `CLAUDE.md` §5.
    private static func markShortcut(
        flags: NSEvent.ModifierFlags,
        characters: String,
        selection: RichTextRange,
        delegate: any RichTextBlockLifecycleDelegate
    ) -> Bool {
        switch (flags, characters) {
        case ([.command], "b"): delegate.richTextViewShouldHandleToggleBold(selection: selection)
        case ([.command], "i"): delegate.richTextViewShouldHandleToggleItalic(selection: selection)
        case ([.command], "u"): delegate.richTextViewShouldHandleToggleUnderline(selection: selection)
        case ([.command, .shift], "x"): delegate.richTextViewShouldHandleToggleStrikethrough(selection: selection)
        case ([.command], "e"): delegate.richTextViewShouldHandleToggleInlineCode(selection: selection)
        case ([.command], "k"): delegate.richTextViewShouldHandleLinkShortcut(selection: selection)
        default: false
        }
    }

    /// Raccourcis de CONVERSION de bloc (Cmd+Opt+0..3) -- voir `markShortcut(flags:
    /// characters:selection:delegate:)`.
    private static func conversionShortcut(
        flags: NSEvent.ModifierFlags,
        characters: String,
        delegate: any RichTextBlockLifecycleDelegate
    ) -> Bool {
        switch (flags, characters) {
        case ([.command, .option], "0"): delegate.richTextViewShouldHandleConvertToParagraph()
        case ([.command, .option], "1"): delegate.richTextViewShouldHandleConvertToHeadingLevel(1)
        case ([.command, .option], "2"): delegate.richTextViewShouldHandleConvertToHeadingLevel(2)
        case ([.command, .option], "3"): delegate.richTextViewShouldHandleConvertToHeadingLevel(3)
        default: false
        }
    }

    // MARK: - Geometrie de la selection (barre de formatage flottante, artboard P1 A)

    /// Rectangle ENGLOBANT (union) de tous les segments de la selection courante, en
    /// coordonnees LOCALES de cette vue (comme `currentCaretVisualColumnX`) -- `nil` si
    /// la selection est vide (caret ponctuel) ou si TextKit 2 n'expose aucun segment
    /// (contenu pas encore mis en page).
    ///
    /// ## Non verifie dans une fenetre reelle
    /// Cette methode est correcte au sens de l'API TextKit 2 documentee
    /// (`NSTextLayoutManager.enumerateTextSegments(in:type:options:using:)` retourne des
    /// rectangles dans le repere du conteneur de texte, identique aux coordonnees
    /// locales de la vue ici -- `textContainerInset = .zero`), mais AUCUNE fenetre n'est
    /// disponible dans cet environnement pour capturer un rectangle reel et le comparer
    /// visuellement a l'artboard. Voir le rapport de livraison.
    func selectionBoundingRectForFormatting() -> CGRect? {
        guard let textLayoutManager else { return nil }
        var union: CGRect?
        for textSelection in textLayoutManager.textSelections {
            for range in textSelection.textRanges {
                textLayoutManager.enumerateTextSegments(in: range, type: .selection) { _, rect, _, _ in
                    guard rect.isNull == false, rect.isInfinite == false else { return true }
                    union = union.map { $0.union(rect) } ?? rect
                    return true
                }
            }
        }
        return union
    }
}
