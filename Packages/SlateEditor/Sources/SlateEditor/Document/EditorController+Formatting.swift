import CoreGraphics
import Foundation
import SlateModel

/// Selection de texte inline courante (voir la documentation de
/// `EditorController.inlineSelection`).
public struct EditorInlineSelection: Equatable, Sendable {
    public let blockID: UUID
    public let range: RichTextRange
    /// Rectangle de la selection dans la `coordinateSpace` nommee partagee de l'editeur
    /// (`NoteDocumentView.blockListCoordinateSpace`), ou `nil` si la geometrie n'a pas pu
    /// etre resolue (voir `RichTextEditingTextView.selectionBoundingRectForFormatting()`)
    /// -- la barre de formatage reste alors simplement invisible (`FormatBarOverlay`),
    /// jamais mal positionnee.
    public let rect: CGRect?
}

/// Demande d'edition de lien en attente (voir la documentation de
/// `EditorController.linkEditRequest`).
public struct LinkEditRequest: Equatable, Sendable {
    public let blockID: UUID
    public let range: RichTextRange
}

/// Formatage inline (docs/07_typographie_formatage.md) : applique/retire une marque sur
/// la selection de texte courante, expose l'etat "actif" pour piloter les boutons de la
/// barre flottante, et porte la selection inline elle-meme (position + geometrie).
///
/// ## Ecart assume avec docs/07 ("FormattingController")
/// La spec de phase nomme un type distinct, `FormattingController`. La structure du
/// projet impose UN SEUL controleur `@Observable` proprietaire de l'etat d'edition
/// (`EditorController`, voir sa documentation de tete) : cette extension suit exactement
/// le meme motif que `EditorController+Selection.swift`/`+SlashMenu.swift` plutot que
/// d'introduire un second type concurrent. Aucune nouvelle surface publique qui ne soit
/// pas portee par `EditorController` lui-meme.
///
/// ## Testable HORS AppKit, meme regle que le reste de `EditorController`
/// Chaque methode prend un `Block` et un `RichTextRange` DEJA converti par la couche
/// AppKit (`RichTextEditingTextView`/`RichTextBlockView.Coordinator`, via
/// `RichTextRange(utf16Range:in:)`) -- jamais un `NSRange` nu. La logique de detection/
/// application elle-meme est deleguee a `FormattingEngine` (pure, sans `Block`/`Note`).
///
/// ## Piege documente : deux lectures de `block.text` sont deux `AttributedString` distincts
/// Chaque methode ci-dessous lit `block.text` UNE SEULE FOIS dans une variable locale
/// (`var text = block.text ?? RichText()`), mute cette copie, puis reecrit `block.text`
/// en une seule affectation finale -- jamais deux acces successifs a `block.text` dont
/// les `AttributedString.Index` seraient ensuite melanges (ils appartiennent a des
/// instances DIFFERENTES d'`AttributedString`, memes si les deux ont le meme contenu :
/// un index de l'une n'est valide sur l'autre que par coincidence de representation
/// interne, jamais garanti).
extension EditorController {
    // MARK: - Selection inline (barre flottante, artboard P1 A)

    /// A appeler par la couche AppKit a CHAQUE deplacement/changement de selection dans
    /// `block` (voir `RichTextBlockView.Coordinator.textViewDidChangeSelection(_:)`).
    /// Une plage VIDE (caret ponctuel) efface la selection inline de CE bloc si elle lui
    /// appartenait deja -- jamais celle d'un AUTRE bloc (defensif, memes garanties que
    /// le reste de ce fichier vis-a-vis du bloc concerne).
    public func updateInlineSelection(for block: Block, range: RichTextRange, rect: CGRect?) {
        guard !range.isEmpty else {
            clearInlineSelection(for: block.id)
            return
        }
        inlineSelection = EditorInlineSelection(blockID: block.id, range: range, rect: rect)
    }

    /// Efface la selection inline ET toute demande d'edition de lien en attente pour
    /// `blockID`, sans effet si elles appartiennent a un autre bloc.
    public func clearInlineSelection(for blockID: UUID) {
        if inlineSelection?.blockID == blockID { inlineSelection = nil }
        if linkEditRequest?.blockID == blockID { linkEditRequest = nil }
    }

    // MARK: - Marques booleennes (gras, italique, souligne, barre, code inline)

    /// `true` si `kind` est present sur TOUTE la plage `range` de `block` (etat "actif"
    /// des boutons de la barre flottante -- voir `FormattingEngine.isMarkActive`).
    public func isMarkActive(_ kind: FormattingMarkKind, in block: Block, range: RichTextRange) -> Bool {
        guard let text = block.text, !range.isEmpty else { return false }
        let attrRange = attributedRange(of: text, range)
        return FormattingEngine.isMarkActive(kind, in: text, range: attrRange)
    }

    /// Bascule `kind` sur `range` : le retire si deja present PARTOUT, l'applique sinon
    /// (comportement bascule attendu, docs/07). Sans effet sur une plage vide (caret
    /// ponctuel -- voir la documentation de tete de fichier de
    /// `RichTextEditingTextView`, "shortcuts sans selection non geres").
    @discardableResult
    public func toggleMark(_ kind: FormattingMarkKind, in block: Block, range: RichTextRange) -> Bool {
        guard !range.isEmpty else { return false }
        var text = block.text ?? RichText()
        let attrRange = attributedRange(of: text, range)
        if FormattingEngine.isMarkActive(kind, in: text, range: attrRange) {
            text.remove(kind.inlineMark, from: attrRange)
        } else {
            text.apply(kind.inlineMark, to: attrRange)
        }
        block.text = text
        persistStructuralChange()
        return true
    }

    // MARK: - Surlignage

    /// Couleur de surlignage commune a TOUTE la plage, `nil` si melangee/absente/vide --
    /// pilote la coche de la palette (artboard P1 B).
    public func activeHighlight(in block: Block, range: RichTextRange) -> SlateHighlightColor? {
        guard let text = block.text, !range.isEmpty else { return nil }
        return FormattingEngine.uniformHighlight(in: text, range: attributedRange(of: text, range))
    }

    /// Applique `color` sur `range`, ou retire tout surlignage si `color` est `nil`
    /// (bouton "Retirer tout le formatage" de la palette n'est PAS ce chemin -- voir
    /// `removeAllFormatting(in:range:)` -- ceci est le retrait CIBLE du surlignage seul,
    /// utilise quand l'utilisateur reclique la pastille deja active).
    public func setHighlight(_ color: SlateHighlightColor?, in block: Block, range: RichTextRange) {
        guard !range.isEmpty else { return }
        var text = block.text ?? RichText()
        let attrRange = attributedRange(of: text, range)
        if let color {
            text.apply(.highlight(color), to: attrRange)
        } else {
            text.remove(.highlight(SlateHighlightColor("")), from: attrRange)
        }
        block.text = text
        persistStructuralChange()
    }

    // MARK: - Couleur de texte

    /// Symmetrique de `activeHighlight(in:range:)` pour la couleur de texte.
    public func activeTextColor(in block: Block, range: RichTextRange) -> SlateTextColor? {
        guard let text = block.text, !range.isEmpty else { return nil }
        return FormattingEngine.uniformTextColor(in: text, range: attributedRange(of: text, range))
    }

    /// Symmetrique de `setHighlight(_:in:range:)` pour la couleur de texte.
    public func setTextColor(_ color: SlateTextColor?, in block: Block, range: RichTextRange) {
        guard !range.isEmpty else { return }
        var text = block.text ?? RichText()
        let attrRange = attributedRange(of: text, range)
        if let color {
            text.apply(.textColor(color), to: attrRange)
        } else {
            text.remove(.textColor(SlateTextColor("")), from: attrRange)
        }
        block.text = text
        persistStructuralChange()
    }

    // MARK: - Lien

    /// Lien commun a TOUTE la plage, `nil` si melange/absent/vide -- pilote a la fois le
    /// popover de survol (URL affichee) et l'etat "desactive" du bouton lien sur une
    /// selection qui couvre plusieurs liens differents (docs/07, "Etats des boutons").
    public func currentLink(in block: Block, range: RichTextRange) -> URL? {
        guard let text = block.text, !range.isEmpty else { return nil }
        return FormattingEngine.uniformLink(in: text, range: attributedRange(of: text, range))
    }

    /// Applique `url` sur `range`, ou retire le lien si `url` est `nil`. Ferme
    /// toujours le popover d'edition de lien en attente (`linkEditRequest`), qu'il
    /// vise ou non ce meme bloc/cette meme plage -- l'action est terminale.
    public func setLink(_ url: URL?, in block: Block, range: RichTextRange) {
        guard !range.isEmpty else { return }
        var text = block.text ?? RichText()
        let attrRange = attributedRange(of: text, range)
        if let url {
            text.apply(.link(url), to: attrRange)
        } else {
            text.remove(.link(FormattingEngine.dummyURL), from: attrRange)
        }
        block.text = text
        persistStructuralChange()
        linkEditRequest = nil
    }

    /// Ouvre le popover d'edition de lien pour `range` (Cmd+K ou bouton "lien" de la
    /// barre flottante). Sans effet sur une plage vide.
    public func requestLinkEditor(in block: Block, range: RichTextRange) {
        guard !range.isEmpty else { return }
        linkEditRequest = LinkEditRequest(blockID: block.id, range: range)
    }

    /// Ferme le popover d'edition de lien sans y appliquer d'action (Echap, clic
    /// exterieur).
    public func dismissLinkEditor() {
        linkEditRequest = nil
    }

    // MARK: - Retirer tout le formatage (palette, artboard P1 B)

    /// Retire les 8 marques inline (gras, italique, souligne, barre, code, surlignage,
    /// couleur de texte, lien) de `range`, sans effet sur une plage vide.
    public func removeAllFormatting(in block: Block, range: RichTextRange) {
        guard !range.isEmpty else { return }
        var text = block.text ?? RichText()
        let attrRange = attributedRange(of: text, range)
        for kind in FormattingMarkKind.allCases {
            text.remove(kind.inlineMark, from: attrRange)
        }
        text.remove(.highlight(SlateHighlightColor("")), from: attrRange)
        text.remove(.textColor(SlateTextColor("")), from: attrRange)
        text.remove(.link(FormattingEngine.dummyURL), from: attrRange)
        block.text = text
        persistStructuralChange()
    }

    // MARK: - Conversion utilitaire (une seule lecture de `block.text`, voir la doc de tete)

    private func attributedRange(of text: RichText, _ range: RichTextRange) -> Range<AttributedString.Index> {
        text.range(charactersOffset: range.lowerBound.characters..<range.upperBound.characters)
    }
}
