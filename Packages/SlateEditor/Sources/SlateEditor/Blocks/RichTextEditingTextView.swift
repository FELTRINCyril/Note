import AppKit
import SlateModel
import SlateUI
import SwiftUI

/// `NSTextView` d'un bloc paragraphe editable, explicitement configure en TextKit 2
/// (`NSTextLayoutManager`/`NSTextContentStorage`, jamais l'ancien `NSLayoutManager`
/// -- exigence de `docs/05_editeur_blocs.md`, sous-etape 5.2, point 1).
///
/// Ce type ne connait ni `Block` ni `RichText` : il expose uniquement des operations
/// AppKit generiques (contenu attribue, dimensionnement intrinseque, apparence). C'est
/// `RichTextBlockView.Coordinator` qui fait le pont avec le modele -- separation
/// deliberee entre "comment un NSTextView de bloc se comporte visuellement" et
/// "comment son contenu se synchronise avec `SlateModel`".
///
/// ## Entree, Retour arriere, fleches, Echap : cycle de vie des blocs (sous-etape 5.3)
/// Ce type intercepte ces touches en overridant les selecteurs `NSResponder` que
/// `NSTextView` appelle deja pour son comportement natif (`insertNewline(_:)`,
/// `deleteBackward(_:)`, `moveUp(_:)`, `moveDown(_:)`, `cancelOperation(_:)`), et
/// delegue la DECISION a `blockLifecycleDelegate` (`RichTextBlockLifecycleDelegate`) --
/// jamais directement a `EditorController`/`Block`, que ce fichier continue
/// volontairement d'ignorer (voir le paragraphe precedent). Si le delegue signale avoir
/// pris la main (retour `true`), le comportement natif AppKit est court-circuite
/// (`super` n'est PAS appele) ; sinon le comportement natif s'execute normalement,
/// exactement comme en 5.2.
@MainActor
final class RichTextEditingTextView: NSTextView {
    /// Le caret est figeable visuellement (spec E4, "Reduce Motion" : "caret fige").
    /// Voir `drawInsertionPoint` : NSTextView ne pilote pas nativement la periode de
    /// clignotement (API privee), ce drapeau est le seul point d'accroche public
    /// disponible -- voir le rapport de livraison pour le detail de cette limite.
    var freezesCaretForReduceMotion = false

    /// Seul point de contact avec le cycle de vie des blocs (`RichTextBlockView.
    /// Coordinator`, qui adapte cet appel vers `EditorController`). `weak` : la vue ne
    /// doit jamais retenir son coordinateur.
    weak var blockLifecycleDelegate: (any RichTextBlockLifecycleDelegate)?

    /// Construit l'instance en explicitant toute la pile TextKit 2 (motif recommande
    /// par Apple pour un `NSTextView` autonome, hors `NSTextView.scrollableTextView()`
    /// qui, lui, construit un `NSScrollView` -- exclu ici, voir doc de tache : "PAS de
    /// NSScrollView autour du NSTextView").
    static func makeTextKit2Instance() -> RichTextEditingTextView {
        let contentStorage = NSTextContentStorage()
        let layoutManager = NSTextLayoutManager()
        contentStorage.addTextLayoutManager(layoutManager)

        let container = NSTextContainer(size: CGSize(width: 0, height: CGFloat.greatestFiniteMagnitude))
        container.lineFragmentPadding = 0
        container.widthTracksTextView = true
        layoutManager.textContainer = container

        let textView = RichTextEditingTextView(frame: .zero, textContainer: container)
        textView.configureAppearance()
        return textView
    }

    private func configureAppearance() {
        isEditable = true
        isSelectable = true
        isRichText = true
        allowsUndo = true
        drawsBackground = false
        textContainerInset = .zero
        isVerticallyResizable = true
        isHorizontallyResizable = false
        autoresizingMask = [.width]
        insertionPointColor = NSColor(SlateColor.caretColor)
        applyTypography()
    }

    // Typographie (`applyTypography(for:)` et ses helpers prives) : voir
    // `RichTextEditingTextView+Typography.swift` -- extrait de ce fichier pour rester
    // sous la limite de longueur de `CLAUDE.md` §5 (fichier separe, pas un second type :
    // tous les helpers y restent `private`, appeles uniquement depuis ce meme fichier
    // voisin).

    /// Taille intrinseque du bloc pour une largeur proposee par SwiftUI (voir
    /// `RichTextBlockView.sizeThatFits`) : point technique central de la sous-etape
    /// 5.2 -- "la vue doit se dimensionner sur son contenu et grandir quand le texte
    /// passe a la ligne", sans `NSScrollView` ni hauteur figee. TextKit 2 calcule cette
    /// hauteur via `usageBoundsForTextContainer`, apres avoir force la mise en page du
    /// document entier (`ensureLayout(for:)`) a la largeur proposee.
    /// `wraps` (voir `applyTypography(for:isChecked:)`) : `false` UNIQUEMENT pour un
    /// bloc `.code` (Phase 8, docs/08_blocs_speciaux.md, "Debordement horizontal...
    /// jamais de retour a la ligne force"). Dans ce cas, `textContainer.size.width` est
    /// deja fixee a l'infini par `applyTypography` et ne doit JAMAIS etre reecrasee ici
    /// par la largeur PROPOSEE (qui, elle, reste bornee a la largeur du bloc) : c'est la
    /// largeur NATURELLE du contenu (`usageBoundsForTextContainer.width`) qui est
    /// remontee a SwiftUI, pour qu'un `ScrollView(.horizontal)` parent (voir
    /// `CodeBlockContentView`) puisse effectivement defiler au lieu de tronquer.
    func intrinsicSize(forProposedWidth proposedWidth: CGFloat?) -> CGSize? {
        guard let textContainer, let textLayoutManager,
              let documentRange = textLayoutManager.textContentManager?.documentRange else {
            return nil
        }

        let wraps = textContainer.widthTracksTextView
        var reportedWidth = textContainer.size.width
        if wraps {
            let width = (proposedWidth?.isFinite == true ? proposedWidth : nil) ?? textContainer.size.width
            guard width > 0 else { return nil }
            if textContainer.size.width != width {
                textContainer.size = CGSize(width: width, height: CGFloat.greatestFiniteMagnitude)
            }
            reportedWidth = width
        }
        textLayoutManager.ensureLayout(for: documentRange)

        let bounds = textLayoutManager.usageBoundsForTextContainer
        let measuredHeight = bounds.height
        let minimumHeight = defaultParagraphStyle?.maximumLineHeight ?? font?.pointSize ?? SlateFont.body.size
        if !wraps {
            reportedWidth = max(bounds.width, minimumHeight)
        }
        return CGSize(width: reportedWidth, height: max(measuredHeight, minimumHeight))
    }

    /// Caret 2 pt (`SlateGeometry.editorCaretWidth`) au lieu du 1 pt natif -- seul point
    /// d'accroche public pour personnaliser la largeur du curseur de saisie (couleur
    /// deja pilotee nativement par `insertionPointColor`, voir `configureAppearance`).
    ///
    /// "Reduce Motion" : quand actif, ce override ignore le parametre `flag` (qui
    /// alterne selon le cycle de clignotement interne, prive) et force `true` -- le
    /// caret reste donc visuellement plein en permanence, ce qui EST le comportement
    /// "clignotement fige" demande. Le clignotement natif lui-meme (periode, activation)
    /// reste hors de portee de l'API publique -- voir le rapport de livraison.
    override func drawInsertionPoint(in rect: NSRect, color: NSColor, turnedOn flag: Bool) {
        var widened = rect
        widened.size.width = SlateGeometry.editorCaretWidth
        super.drawInsertionPoint(in: widened, color: color, turnedOn: freezesCaretForReduceMotion ? true : flag)
    }

    // MARK: - Interception clavier (sous-etape 5.3)

    override func insertNewline(_ sender: Any?) {
        // Menu "/" (Phase 6) : menu ouvert = Entree valide la commande, jamais le split.
        if blockLifecycleDelegate?.richTextViewShouldHandleSlashMenuReturn() == true {
            return
        }
        // Markdown natif (Phase 15, docs/15_markdown_natif.md) : motifs sans espace
        // (`` ``` ``, `---`) qui ne se declenchent qu'a l'Entree -- AVANT le split de
        // bloc normal, jamais apres (une conversion prend la main sur cette pression
        // d'Entree, elle ne doit pas EN PLUS scinder le bloc).
        if blockLifecycleDelegate?.richTextViewShouldHandleMarkdownReturnTrigger(undoManager: undoManager) == true {
            return
        }
        // Frontiere AppKit -> logique pure (voir la documentation de `RichTextOffset`) :
        // `selectedRange().location` est TOUJOURS en unites UTF-16, jamais transmis
        // sans conversion au-dela de ce point -- defaut le plus grave de la revue
        // finale de Phase 5 (un emoji/drapeau avant le caret faisait scinder le bloc au
        // mauvais endroit, silencieusement).
        let caretOffset = RichTextOffset(utf16Offset: selectedRange().location, in: string)
        if blockLifecycleDelegate?.richTextViewShouldHandleReturn(caretOffset: caretOffset) == true {
            return
        }
        super.insertNewline(sender)
    }

    /// Seul le Retour arriere en tete de bloc (caret SANS selection, position absolue
    /// 0 dans le contenu du bloc -- pas simplement en tete de ligne visuelle) est
    /// intercepte : la spec E4 parle de "tete de bloc", jamais de tete de ligne.
    override func deleteBackward(_ sender: Any?) {
        let selection = selectedRange()
        guard selection.length == 0, selection.location == 0 else {
            super.deleteBackward(sender)
            return
        }
        if blockLifecycleDelegate?.richTextViewShouldHandleBackspaceAtStart() == true {
            return
        }
        super.deleteBackward(sender)
    }

    /// N'intercepte que depuis la PREMIERE ligne visuelle (`isCaretOnFirstVisualLine`) :
    /// a l'interieur d'un bloc multi-lignes, la fleche haut doit d'abord naviguer DANS
    /// le bloc -- comportement natif, laisse a `super` -- et ne changer de bloc qu'au
    /// franchissement du bord superieur (spec E4).
    override func moveUp(_ sender: Any?) {
        // Menu "/" (Phase 6) : AVANT `isCaretOnFirstVisualLine` -- menu ouvert = fleche
        // deplace la selection DANS le menu, depuis n'importe quelle ligne du bloc.
        if blockLifecycleDelegate?.richTextViewShouldHandleSlashMenuMoveSelection(.up) == true {
            return
        }
        if isCaretOnFirstVisualLine, let x = currentCaretVisualColumnX,
           blockLifecycleDelegate?.richTextViewShouldHandleMoveUp(visualColumnX: x) == true {
            return
        }
        super.moveUp(sender)
    }

    /// Symmetrique de `moveUp(_:)` pour la DERNIERE ligne visuelle -- meme priorite
    /// absolue du menu "/" en tete, meme raison.
    override func moveDown(_ sender: Any?) {
        if blockLifecycleDelegate?.richTextViewShouldHandleSlashMenuMoveSelection(.down) == true {
            return
        }
        if isCaretOnLastVisualLine, let x = currentCaretVisualColumnX,
           blockLifecycleDelegate?.richTextViewShouldHandleMoveDown(visualColumnX: x) == true {
            return
        }
        super.moveDown(sender)
    }

    /// Selecteur `NSResponder` invoque par Maj+fleche haut (sous-etape 5.6, spec E4
    /// "Accessibilite" : extension de la selection multi-blocs au clavier). Meme regle
    /// de frontiere que `moveUp(_:)` : n'intercepte que depuis la PREMIERE ligne
    /// visuelle -- a l'interieur d'un bloc multi-lignes, Maj+fleche haut doit d'abord
    /// etendre la selection de TEXTE native (comportement natif, laisse a `super`).
    override func moveUpAndModifySelection(_ sender: Any?) {
        if isCaretOnFirstVisualLine,
           blockLifecycleDelegate?.richTextViewShouldHandleExtendSelectionUp() == true {
            return
        }
        super.moveUpAndModifySelection(sender)
    }

    /// Symmetrique de `moveUpAndModifySelection(_:)` pour la DERNIERE ligne visuelle
    /// (Maj+fleche bas).
    override func moveDownAndModifySelection(_ sender: Any?) {
        if isCaretOnLastVisualLine,
           blockLifecycleDelegate?.richTextViewShouldHandleExtendSelectionDown() == true {
            return
        }
        super.moveDownAndModifySelection(sender)
    }

    /// Selecteur `NSResponder` invoque par Echap dans un `NSTextView` autonome (spec E4 :
    /// "Echap sort de l'edition et selectionne le bloc entier").
    override func cancelOperation(_ sender: Any?) {
        // Menu "/" (Phase 6) : menu ouvert = Echap ferme le menu SEUL, jamais la
        // selection du bloc entier de la Phase 5 ci-dessous.
        if blockLifecycleDelegate?.richTextViewShouldHandleSlashMenuEscape() == true {
            return
        }
        if blockLifecycleDelegate?.richTextViewShouldHandleCancelEditing() == true {
            return
        }
        super.cancelOperation(sender)
    }

    /// Tab (Phase 8, docs/08_blocs_speciaux.md, "Imbrication") : indente l'item de liste
    /// courant. Si le delegue ne prend pas la main (bloc pas un item de liste, ou pas de
    /// frere precedent), le comportement natif s'execute -- insertion d'une tabulation
    /// litterale, comme un `NSTextView` ordinaire.
    override func insertTab(_ sender: Any?) {
        if blockLifecycleDelegate?.richTextViewShouldHandleIndent() == true { return }
        super.insertTab(sender)
    }

    /// Maj+Tab : symmetrique de `insertTab(_:)` pour la desindentation.
    override func insertBacktab(_ sender: Any?) {
        if blockLifecycleDelegate?.richTextViewShouldHandleOutdent() == true { return }
        super.insertBacktab(sender)
    }

    /// Cmd+V (Phase 15, docs/15_markdown_natif.md, "Coller du markdown -> conversion
    /// optionnelle en blocs"). Ne lit que `.string` du pasteboard general : un collage
    /// d'image (`.png`/`.tiff`, Phase 9) ou de RTF ne passe JAMAIS par cette branche,
    /// `super.paste(sender)` s'en charge exactement comme avant cette phase -- aucune
    /// regression possible sur ces deux chemins, ni sur un collage de texte SANS syntaxe
    /// markdown (le delegue retourne alors `false` de son propre chef).
    override func paste(_ sender: Any?) {
        if let pasteboardText = NSPasteboard.general.string(forType: .string) {
            let range = RichTextRange(utf16Range: selectedRange(), in: string)
            if blockLifecycleDelegate?.richTextViewShouldHandleMarkdownPaste(
                text: pasteboardText, replacingRange: range, undoManager: undoManager
            ) == true {
                return
            }
        }
        super.paste(sender)
    }

    // MARK: - Raccourcis de formatage (docs/07_typographie_formatage.md)
    //
    // `performKeyEquivalent(with:)` est le point d'accroche recommande pour des
    // combinaisons Cmd (voir la tache) : contrairement a `insertNewline(_:)`/
    // `deleteBackward(_:)` (des ACTIONS `NSResponder` que `NSTextView` appelle deja),
    // Cmd+B/I/U/E/K et Cmd+Opt+0..3 ne correspondent a AUCUN selecteur natif que
    // `NSTextView` invoquerait de lui-meme -- il faut intercepter l'evenement clavier
    // brut avant qu'AppKit ne le laisse tomber silencieusement (aucun Format-menu n'est
    // cable dans ce projet, voir CLAUDE.md -- perimetre de l'agent editeur, pas de la
    // barre de menus).

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if handleFormattingKeyEquivalent(event) { return true }
        return super.performKeyEquivalent(with: event)
    }

    // `handleFormattingKeyEquivalent(_:)` et `selectionBoundingRectForFormatting()` :
    // voir `RichTextEditingTextView+Formatting.swift` -- meme motif d'extraction que la
    // typographie ci-dessus (fichier separe, pas un second type).

    // MARK: - Application d'un `EditorCaretRequest.Placement` (appele par le Coordinator)

    /// Place le caret a la position demandee, en convertissant `.visualColumn` via la
    /// geometrie REELLE du layout (`characterIndexForInsertion(at:)`), jamais par un
    /// simple offset de caracteres -- exigence explicite de la spec E4 pour la
    /// conservation de colonne entre blocs. Rend aussi cette vue premier repondant :
    /// c'est ICI, et seulement ici, que le focus AppKit traverse effectivement d'un
    /// bloc a l'autre (le "focus" SwiftUI/`EditorController` n'est qu'une intention).
    func applyCaretPlacement(_ placement: EditorCaretRequest.Placement) {
        let length = textStorage?.length ?? 0
        let targetLocation: Int
        switch placement {
        case let .offset(offset):
            // Frontiere logique pure -> AppKit (voir la documentation de
            // `RichTextOffset`) : `offset` est un compte de CARACTERES, `setSelectedRange`
            // (ci-dessous) attend un `NSRange` en UTF-16 -- conversion explicite, jamais
            // un simple passage direct de l'un a l'autre.
            targetLocation = max(0, min(offset.utf16Offset(in: string), length))
        case .end:
            targetLocation = length
        case let .visualColumn(x, edge):
            let y: CGFloat = edge == .top ? 0 : max(bounds.height - 1, 0)
            let index = characterIndexForInsertion(at: CGPoint(x: x, y: y))
            targetLocation = max(0, min(index, length))
        }
        window?.makeFirstResponder(self)
        setSelectedRange(NSRange(location: targetLocation, length: 0))
    }

    // MARK: - Detection de la premiere/derniere ligne VISUELLE (TextKit 2)
    //
    // Detecter "je suis sur la premiere/derniere ligne visuelle" en TextKit 2 n'a pas
    // d'API directe ("suis-je sur la derniere ligne ?"). Methode retenue, idiomatique
    // TextKit 2 : enumerer les FRAGMENTS de mise en page du document
    // (`NSTextLayoutFragment`, un par ligne visuelle affichee -- PAS par paragraphe :
    // un paragraphe qui retombe a la ligne produit plusieurs fragments), puis verifier
    // si celui qui contient le caret est le tout premier/dernier enumere. Un bloc de ce
    // projet n'a jamais plus de quelques lignes : re-enumerer a chaque pression de
    // fleche reste negligeable, pas besoin de mise en cache.

    private var isCaretOnFirstVisualLine: Bool {
        guard let fragment = caretLayoutFragment(), let first = layoutFragments().first else { return true }
        return fragment === first
    }

    private var isCaretOnLastVisualLine: Bool {
        guard let fragment = caretLayoutFragment(), let last = layoutFragments().last else { return true }
        return fragment === last
    }

    private func layoutFragments() -> [NSTextLayoutFragment] {
        guard let textLayoutManager, let documentRange = textLayoutManager.textContentManager?.documentRange else {
            return []
        }
        var fragments: [NSTextLayoutFragment] = []
        textLayoutManager.enumerateTextLayoutFragments(
            from: documentRange.location,
            options: [.ensuresLayout]
        ) { fragment in
            fragments.append(fragment)
            return true
        }
        return fragments
    }

    private func caretLayoutFragment() -> NSTextLayoutFragment? {
        guard let textLayoutManager,
              let caretLocation = textLayoutManager.textSelections.first?.textRanges.first?.location else {
            return nil
        }
        return layoutFragments().first { $0.rangeInElement.contains(caretLocation) }
    }

    /// Abscisse LOCALE (coordonnees de CE `NSTextView`) du caret courant, portable d'un
    /// bloc a l'autre (voir la documentation de `EditorCaretRequest.Placement.
    /// visualColumn`). `firstRect(forCharacterRange:actualRange:)` est une API
    /// `NSTextInputClient` generique : elle fonctionne quel que soit le moteur de mise
    /// en page sous-jacent (TextKit 1 ou 2), mais renvoie des coordonnees ECRAN --
    /// converties ici en coordonnees locales.
    private var currentCaretVisualColumnX: CGFloat? {
        guard let window else { return nil }
        let caretRange = selectedRange()
        let caretNSRange = NSRange(location: caretRange.location, length: 0)
        let screenRect = firstRect(forCharacterRange: caretNSRange, actualRange: nil)
        guard screenRect != .zero else { return nil }
        let windowRect = window.convertFromScreen(screenRect)
        let localRect = convert(windowRect, from: nil)
        return localRect.midX
    }
}
