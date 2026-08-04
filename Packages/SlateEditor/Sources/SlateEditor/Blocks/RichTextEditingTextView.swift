import AppKit
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

    /// Police et interligne du corps de bloc (design/tokens.md §16, spec E4 : "Corps
    /// 15 pt, interligne 1,5"). Rappele a chaque `updateNSView` (voir
    /// `RichTextBlockView`) plutot qu'une seule fois a la creation : c'est la seule
    /// facon de suivre un changement de Dynamic Type systeme en cours de vie de la vue,
    /// AppKit n'offrant pas de notification dediee equivalente a l'environnement
    /// SwiftUI `\.dynamicTypeSize` pour un `NSTextView` autonome.
    func applyTypography() {
        let bodyFont = Self.scaledBodyFont()
        let paragraphStyle = Self.bodyParagraphStyle(for: bodyFont)
        font = bodyFont
        textColor = NSColor(SlateColor.textPrimary)
        defaultParagraphStyle = paragraphStyle
        typingAttributes = [
            .font: bodyFont,
            .foregroundColor: NSColor(SlateColor.textPrimary),
            .paragraphStyle: paragraphStyle
        ]
    }

    /// Approxime la mise a l'echelle Dynamic Type de `SlateFont.body`
    /// (`@ScaledMetric(wrappedValue: 15, relativeTo: .body)`, cf. `SlateFont.swift`)
    /// pour un `NSTextView` autonome, sans equivalent direct de `@ScaledMetric` en
    /// AppKit pur. `NSFont.preferredFont(forTextStyle: .body)` est l'API AppKit qui
    /// suit reellement le reglage systeme "Texte plus grand" ; `NSFont.systemFontSize`
    /// (13 pt) est la taille de reference macOS pour ce style a l'echelle 100 % --
    /// meme principe de calcul de ratio que `@ScaledMetric`, applique a la taille de
    /// base du token (15 pt) plutot qu'a la taille systeme par defaut.
    private static func scaledBodyFont() -> NSFont {
        let referenceSize = NSFont.systemFontSize
        let preferredBodySize = NSFont.preferredFont(forTextStyle: .body).pointSize
        let scale = referenceSize > 0 ? preferredBodySize / referenceSize : 1
        return NSFont.systemFont(ofSize: SlateFont.body.size * scale)
    }

    /// Interligne de 1,5 (`SlateGeometry.editorParagraphLineHeight`) impose via les
    /// bornes min/max de `NSParagraphStyle` -- l'equivalent AppKit du `.lineSpacing`
    /// SwiftUI utilise par `ParagraphBlockContentView` en lecture seule.
    private static func bodyParagraphStyle(for font: NSFont) -> NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        let lineHeight = font.pointSize * SlateGeometry.editorParagraphLineHeight
        style.minimumLineHeight = lineHeight
        style.maximumLineHeight = lineHeight
        return style
    }

    /// Taille intrinseque du bloc pour une largeur proposee par SwiftUI (voir
    /// `RichTextBlockView.sizeThatFits`) : point technique central de la sous-etape
    /// 5.2 -- "la vue doit se dimensionner sur son contenu et grandir quand le texte
    /// passe a la ligne", sans `NSScrollView` ni hauteur figee. TextKit 2 calcule cette
    /// hauteur via `usageBoundsForTextContainer`, apres avoir force la mise en page du
    /// document entier (`ensureLayout(for:)`) a la largeur proposee.
    func intrinsicSize(forProposedWidth proposedWidth: CGFloat?) -> CGSize? {
        guard let textContainer, let textLayoutManager,
              let documentRange = textLayoutManager.textContentManager?.documentRange else {
            return nil
        }

        let width = (proposedWidth?.isFinite == true ? proposedWidth : nil) ?? textContainer.size.width
        guard width > 0 else { return nil }

        if textContainer.size.width != width {
            textContainer.size = CGSize(width: width, height: CGFloat.greatestFiniteMagnitude)
        }
        textLayoutManager.ensureLayout(for: documentRange)

        let measuredHeight = textLayoutManager.usageBoundsForTextContainer.height
        let minimumHeight = defaultParagraphStyle?.maximumLineHeight ?? font?.pointSize ?? SlateFont.body.size
        return CGSize(width: width, height: max(measuredHeight, minimumHeight))
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
        if isCaretOnFirstVisualLine, let x = currentCaretVisualColumnX,
           blockLifecycleDelegate?.richTextViewShouldHandleMoveUp(visualColumnX: x) == true {
            return
        }
        super.moveUp(sender)
    }

    /// Symmetrique de `moveUp(_:)` pour la DERNIERE ligne visuelle.
    override func moveDown(_ sender: Any?) {
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
        if blockLifecycleDelegate?.richTextViewShouldHandleCancelEditing() == true {
            return
        }
        super.cancelOperation(sender)
    }

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

/// Delegue informe des franchissements de bloc au clavier (Entree, Retour arriere en
/// debut de bloc, fleches haut/bas aux bords, Echap) -- seul point de contact entre ce
/// fichier (generique, ignore `Block`/`SlateModel`/`EditorController`, voir sa
/// documentation de tete) et le cycle de vie des blocs. Implemente par
/// `RichTextBlockView.Coordinator`, qui adapte ces appels vers `EditorController`.
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
}
