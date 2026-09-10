import CoreGraphics
import SlateModel

/// Delegue informe des franchissements de bloc au clavier (Entree, Retour arriere en
/// debut de bloc, fleches haut/bas aux bords, Echap) et du formatage inline (Phase 7) --
/// seul point de contact entre `RichTextEditingTextView` (generique, ignore
/// `Block`/`SlateModel`/`EditorController`, voir sa documentation de tete) et le cycle
/// de vie des blocs. Implemente par `RichTextBlockView.Coordinator`, qui adapte ces
/// appels vers `EditorController`.
///
/// Extrait de `RichTextEditingTextView.swift` (Phase 7) pour rester sous la limite de
/// longueur de fichier de `CLAUDE.md` §5 : un protocole et son unique conformant
/// n'ont pas besoin de partager le meme fichier.
@MainActor
protocol RichTextBlockLifecycleDelegate: AnyObject {
    /// Entree pressee. `caretOffset` : position du caret (0-based, en CARACTERES,
    /// `RichTextOffset` -- voir sa documentation) au moment de l'appui. Retourne `true`
    /// si le cycle de vie a pris la main (le retour a la ligne natif ne doit alors PAS
    /// s'executer par-dessus).
    func richTextViewShouldHandleReturn(caretOffset: RichTextOffset) -> Bool

    /// Retour arriere presse alors que le caret est EXACTEMENT en debut de bloc (aucune
    /// selection) -- precondition deja verifiee par l'appelant. Retourne `true` si le
    /// cycle de vie a pris la main (fusion/suppression).
    func richTextViewShouldHandleBackspaceAtStart() -> Bool

    /// Fleche haut alors que le caret est deja sur la PREMIERE ligne visuelle du bloc.
    /// `visualColumnX` : abscisse locale du caret, pour que le bloc precedent puisse s'y
    /// aligner (spec E4 : "conservent la colonne visuelle"). Retourne `true` si la
    /// navigation inter-bloc a pris la main.
    func richTextViewShouldHandleMoveUp(visualColumnX: CGFloat) -> Bool

    /// Symmetrique de ci-dessus pour la fleche bas depuis la DERNIERE ligne visuelle.
    func richTextViewShouldHandleMoveDown(visualColumnX: CGFloat) -> Bool

    /// Echap presse en cours d'edition : sort de l'edition, selectionne le bloc entier.
    /// Retourne `true` (toujours pris en charge par le cycle de vie de bloc).
    func richTextViewShouldHandleCancelEditing() -> Bool

    /// Maj+fleche haut alors que le caret est deja sur la PREMIERE ligne visuelle du
    /// bloc (sous-etape 5.6, accessibilite clavier de la selection multi-blocs).
    /// Retourne `true` si l'extension de selection inter-bloc a pris la main.
    func richTextViewShouldHandleExtendSelectionUp() -> Bool

    /// Symmetrique de ci-dessus pour Maj+fleche bas depuis la DERNIERE ligne visuelle.
    func richTextViewShouldHandleExtendSelectionDown() -> Bool

    // MARK: - Menu "/" (Phase 6, 6.4) : priorite absolue, interrogees en TETE de
    // `insertNewline`/`moveUp`/`moveDown`/`cancelOperation`. `false` de son propre chef
    // si aucun menu n'est ouvert pour ce bloc (meme motif que `richTextViewShouldHandleMoveUp`).

    /// Fleche haut/bas menu ouvert : deplace la selection DANS le menu, depuis
    /// N'IMPORTE QUELLE ligne (contrairement a `richTextViewShouldHandleMoveUp`/`Down`).
    func richTextViewShouldHandleSlashMenuMoveSelection(_ direction: BlockSelectionDirection) -> Bool
    /// Entree menu ouvert : valide l'item mis en avant plutot que de scinder le bloc.
    func richTextViewShouldHandleSlashMenuReturn() -> Bool
    /// Echap menu ouvert : ferme le menu SEUL, sans selectionner le bloc entier.
    func richTextViewShouldHandleSlashMenuEscape() -> Bool

    // MARK: - Raccourcis de formatage (Phase 7, docs/07_typographie_formatage.md)
    //
    // `selection` : plage de CARACTERES DEJA CONVERTIE par l'appelant (voir
    // `RichTextEditingTextView+Formatting.swift`), jamais un `NSRange` nu -- meme
    // frontiere que `richTextViewShouldHandleReturn(caretOffset:)`. Retourne toujours
    // `true` (l'evenement clavier est TOUJOURS consomme par ce projet, aucun
    // Format-menu natif ne doit prendre le relais) -- l'implementation elle-meme est
    // sans effet observable si `selection` est vide (voir
    // `EditorController.toggleMark(_:in:range:)`).

    func richTextViewShouldHandleToggleBold(selection: RichTextRange) -> Bool
    func richTextViewShouldHandleToggleItalic(selection: RichTextRange) -> Bool
    func richTextViewShouldHandleToggleUnderline(selection: RichTextRange) -> Bool
    func richTextViewShouldHandleToggleStrikethrough(selection: RichTextRange) -> Bool
    func richTextViewShouldHandleToggleInlineCode(selection: RichTextRange) -> Bool
    /// Cmd+K : ouvre le popover d'edition de lien (`EditorController.requestLinkEditor`).
    func richTextViewShouldHandleLinkShortcut(selection: RichTextRange) -> Bool
    /// Cmd+Opt+0 : convertit le bloc en paragraphe (`EditorController.convertBlock`).
    func richTextViewShouldHandleConvertToParagraph() -> Bool
    /// Cmd+Opt+1/2/3 : convertit le bloc en Titre `level` (1 a 3 uniquement -- voir
    /// docs/07_typographie_formatage.md, aucun raccourci demande pour H4-H6).
    func richTextViewShouldHandleConvertToHeadingLevel(_ level: Int) -> Bool
}
