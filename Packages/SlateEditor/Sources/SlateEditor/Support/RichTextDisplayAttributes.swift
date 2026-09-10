import AppKit
import SlateModel
import SlateUI

/// Traduit les marques de formatage Slate (`InlineMark`, `SlateModel`) en attributs de
/// rendu AppKit REELS (police en gras/italique/mono, `.underlineStyle`,
/// `.strikethroughStyle`, `.backgroundColor`, `.foregroundColor`) sur un
/// `NSMutableAttributedString` deja construit par le pont standard
/// (`NSAttributedString(text.attributedString, including: AttributeScopes.SlateAttributes.self)`,
/// voir `RichTextBlockView.Coordinator.apply(_:to:)`).
///
/// ## Pourquoi une traduction manuelle est necessaire (piege documente de la tache)
/// Les attributs custom Slate (`slateHighlight`, `slateTextColor`, `slateInlineCode`,
/// `slateUnderline`) et `inlinePresentationIntent` (Foundation, gras/italique/barre)
/// survivent au pont `AttributedString` -> `NSAttributedString` comme des cles CUSTOM --
/// `NSTextView`/AppKit ne les reconnait pas nativement (seuls `.font`,
/// `.foregroundColor`, `.backgroundColor`, `.underlineStyle`, `.strikethroughStyle`... ont
/// un effet visuel pour TextKit). Sans cette traduction, un bloc porterait bien les
/// marques dans le modele mais resterait visuellement en clair. Cette traduction n'est
/// QU'un AJOUT d'attributs visuels sur `mutable` : elle ne retire jamais les cles Slate
/// deja presentes (necessaires a `textDidChange(_:)` pour reconstruire un `RichText`
/// fidele au prochain aller-retour -- la PERSISTANCE des marques n'est donc pas affectee
/// par ce fichier).
///
/// Lit les valeurs typees directement sur `text.attributedString.runs` (jamais sur le
/// `NSAttributedString` deja bridge) : `AttributedString.Runs.Run` expose
/// `inlinePresentationIntent`/`slateUnderline`/`slateInlineCode`/`slateHighlight`/
/// `slateTextColor`/`link` comme des proprietes FORTEMENT TYPEES (voir
/// `AttributeDynamicLookup`, `SlateInlineAttributes.swift`), sans avoir a deviner le nom
/// de cle Objective-C que Foundation choisit pour `inlinePresentationIntent` cote pont.
enum RichTextDisplayAttributes {
    /// - Parameters:
    ///   - mutable: cible, DEJA porteuse du texte et des attributs Slate/Foundation
    ///     bridges (voir la documentation de tete de fichier).
    ///   - text: source de verite pour les runs -- l'appelant garantit que `mutable` a
    ///     ete construit a partir de ce MEME `text` (memes caracteres, meme ordre), voir
    ///     `RichTextBlockView.Coordinator.apply(_:to:)`.
    ///   - baseFont: police de base du bloc, deja parametree par type de bloc (voir
    ///     `RichTextEditingTextView.applyTypography(for:)`), point de depart pour
    ///     deriver les variantes gras/italique/mono.
    static func apply(to mutable: NSMutableAttributedString, from text: RichText, baseFont: NSFont) {
        let plainText = text.plainText
        for run in text.attributedString.runs {
            guard let range = nsRange(of: run.range, in: text, plainText: plainText, totalLength: mutable.length) else {
                continue
            }
            applyFont(for: run, baseFont: baseFont, to: mutable, range: range)
            applyUnderlineAndStrikethrough(for: run, to: mutable, range: range)
            applyHighlightAndTextColor(for: run, to: mutable, range: range)
            applyLink(for: run, to: mutable, range: range)
        }
    }

    /// Convertit la plage de CARACTERES du run (`AttributedString.Index`) en `NSRange`
    /// UTF-16 -- meme frontiere que `RichTextOffset`, appliquee ici au niveau d'un run
    /// plutot qu'a une position ponctuelle.
    private static func nsRange(
        of range: Range<AttributedString.Index>,
        in text: RichText,
        plainText: String,
        totalLength: Int
    ) -> NSRange? {
        let characters = text.attributedString.characters
        let lowerCharacters = characters.distance(from: text.attributedString.startIndex, to: range.lowerBound)
        let upperCharacters = characters.distance(from: text.attributedString.startIndex, to: range.upperBound)
        let lowerUTF16 = RichTextOffset(characters: lowerCharacters).utf16Offset(in: plainText)
        let upperUTF16 = RichTextOffset(characters: upperCharacters).utf16Offset(in: plainText)
        let nsRange = NSRange(location: lowerUTF16, length: upperUTF16 - lowerUTF16)
        guard nsRange.length > 0, nsRange.location + nsRange.length <= totalLength else { return nil }
        return nsRange
    }

    private static func applyFont(
        for run: AttributedString.Runs.Run,
        baseFont: NSFont,
        to mutable: NSMutableAttributedString,
        range: NSRange
    ) {
        let intent = run.inlinePresentationIntent ?? []
        var font = run.slateInlineCode == true ? monoFont(matching: baseFont) : baseFont
        var traits: NSFontDescriptor.SymbolicTraits = []
        // Une marque UTILISATEUR de gras reste un vrai `.bold` de police : distinct de
        // l'epaisseur de BASE du bloc (Semibold pour H2-H6, deja geree par
        // `applyTypography(for:)`), voir artboard P1 D.
        if intent.contains(.stronglyEmphasized) { traits.insert(.bold) }
        if intent.contains(.emphasized) { traits.insert(.italic) }
        if !traits.isEmpty,
           let descriptor = font.fontDescriptor.withSymbolicTraits(traits) as NSFontDescriptor?,
           let traitFont = NSFont(descriptor: descriptor, size: font.pointSize) {
            font = traitFont
        }
        mutable.addAttribute(.font, value: font, range: range)
    }

    /// `font.mono` (design/tokens.md §9) a la taille RELATIVE de `baseFont` (le rapport
    /// mono/corps du design system, pas une taille absolue) : un mot en code inline dans
    /// un H1 doit rester proportionnellement plus petit que le H1, pas retomber sur la
    /// taille absolue du corps de texte.
    private static func monoFont(matching baseFont: NSFont) -> NSFont {
        let scale = SlateFont.mono.size / SlateFont.body.size
        return NSFont.monospacedSystemFont(ofSize: baseFont.pointSize * scale, weight: .regular)
    }

    private static func applyUnderlineAndStrikethrough(
        for run: AttributedString.Runs.Run,
        to mutable: NSMutableAttributedString,
        range: NSRange
    ) {
        if run.slateUnderline == true {
            mutable.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: range)
        }
        // Barre conserve la couleur du texte (docs/07) : aucun `.strikethroughColor`
        // ajoute ici, TextKit retombe par defaut sur `.foregroundColor` du run.
        if run.inlinePresentationIntent?.contains(.strikethrough) == true {
            mutable.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: range)
        }
    }

    private static func applyHighlightAndTextColor(
        for run: AttributedString.Runs.Run,
        to mutable: NSMutableAttributedString,
        range: NSRange
    ) {
        if run.slateInlineCode == true {
            mutable.addAttribute(.backgroundColor, value: NSColor(SlateColor.codeInlineBackground), range: range)
            mutable.addAttribute(.foregroundColor, value: NSColor(SlateColor.codeInlineText), range: range)
            return
        }
        if let highlight = run.slateHighlight,
           let color = SlateColor.highlightBackground(forIdentifier: highlight.value) {
            mutable.addAttribute(.backgroundColor, value: NSColor(color), range: range)
        }
        if let textColor = run.slateTextColor,
           let color = SlateColor.textColorBackground(forIdentifier: textColor.value) {
            mutable.addAttribute(.foregroundColor, value: NSColor(color), range: range)
        }
    }

    /// Couleur `text.link` (design/tokens.md §2, variante lisible imposee par la note de
    /// §7). Le soulignement AU SURVOL (docs/07) exigerait un suivi de pointeur
    /// (`NSTrackingArea`) hors perimetre de ce rendu STATIQUE des attributs : le lien
    /// reste souligne en permanence, ce qui satisfait la regle "jamais la couleur seule".
    private static func applyLink(
        for run: AttributedString.Runs.Run,
        to mutable: NSMutableAttributedString,
        range: NSRange
    ) {
        guard run.link != nil else { return }
        mutable.addAttribute(
            .underlineStyle,
            value: NSUnderlineStyle.single.rawValue,
            range: range
        )
        mutable.addAttribute(.foregroundColor, value: NSColor(SlateColor.textLink), range: range)
    }
}
