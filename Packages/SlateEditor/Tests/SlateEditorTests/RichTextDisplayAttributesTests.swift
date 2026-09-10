import AppKit
import SlateModel
import SlateUI
import Testing

@testable import SlateEditor

/// `RichTextDisplayAttributes.apply(to:from:baseFont:)` (docs/07_typographie_formatage.md)
/// traduit les marques Slate en attributs de rendu REELS pour TextKit (`.font`,
/// `.foregroundColor`, `.backgroundColor`, `.underlineStyle`, `.strikethroughStyle`) --
/// c'est le SEUL endroit ou une marque stockee correctement dans le modele pourrait
/// pourtant rester invisible a l'ecran (cle custom sans effet visuel propre, voir la
/// documentation de tete du fichier). Aucun `NSTextView`/fenetre necessaire ici : ce sont
/// des manipulations d'`NSMutableAttributedString`/`NSFont` pures, entierement testables
/// hors AppKit-UI.
@Suite("RichTextDisplayAttributes")
struct RichTextDisplayAttributesTests {
    /// Pas une `static let` (CLAUDE.md §5, concurrence stricte Swift 6) : `NSFont` n'est
    /// pas `Sendable`, une propriete statique partagerait un etat mutable non protege
    /// entre les tests. Reconstruit a chaque appel, cout negligeable.
    private var baseFont: NSFont { NSFont.systemFont(ofSize: 15) }

    private func render(_ text: RichText) -> NSMutableAttributedString {
        let mutable = NSMutableAttributedString(string: text.plainText)
        RichTextDisplayAttributes.apply(to: mutable, from: text, baseFont: baseFont)
        return mutable
    }

    /// Composantes RGBA resolues d'un `NSColor`, regroupees pour eviter un tuple a 4
    /// membres (`large_tuple`, `CLAUDE.md` §5).
    private struct RGBAComponents: Equatable {
        let red: CGFloat
        let green: CGFloat
        let blue: CGFloat
        let alpha: CGFloat

        func isClose(to other: Self, tolerance: CGFloat = 0.001) -> Bool {
            abs(red - other.red) < tolerance
                && abs(green - other.green) < tolerance
                && abs(blue - other.blue) < tolerance
                && abs(alpha - other.alpha) < tolerance
        }
    }

    /// Composantes RGBA d'un `NSColor` DYNAMIQUE (les tokens `SlateColor`/`slateAdaptiveColor`
    /// le sont tous), resolues sous une apparence FIXE. `NSColor.==` compare l'IDENTITE du
    /// proxy dynamique sous-jacent, pas la couleur resolue : deux `NSColor(sameSwiftUIColor)`
    /// obtenus par deux appels distincts ne sont JAMAIS `==`, meme s'ils resolvent
    /// exactement a la meme teinte -- piege decouvert en ecrivant ce test, voir le
    /// rapport de revue de Phase 7.
    private func resolvedComponents(_ color: NSColor, appearance: NSAppearance.Name) throws -> RGBAComponents {
        let resolvedAppearance = try #require(NSAppearance(named: appearance))
        var result = RGBAComponents(red: 0, green: 0, blue: 0, alpha: 0)
        resolvedAppearance.performAsCurrentDrawingAppearance {
            let resolved = color.usingColorSpace(.deviceRGB) ?? color
            result = RGBAComponents(
                red: resolved.redComponent,
                green: resolved.greenComponent,
                blue: resolved.blueComponent,
                alpha: resolved.alphaComponent
            )
        }
        return result
    }

    private func expectSameColor(
        _ lhs: NSColor,
        _ rhs: NSColor,
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws {
        for appearance: NSAppearance.Name in [.aqua, .darkAqua] {
            let lhsComponents = try resolvedComponents(lhs, appearance: appearance)
            let rhsComponents = try resolvedComponents(rhs, appearance: appearance)
            #expect(lhsComponents.isClose(to: rhsComponents), sourceLocation: sourceLocation)
        }
    }

    @Test("Le gras applique le trait .bold a la police, sans toucher le reste de la plage")
    func boldAppliesFontTrait() {
        var text = RichText(plainText: "Bonjour")
        text.apply(.bold, to: text.range(charactersOffset: 0..<3))
        let rendered = render(text)

        let boldFont = rendered.attribute(.font, at: 0, effectiveRange: nil) as? NSFont
        #expect(boldFont?.fontDescriptor.symbolicTraits.contains(.bold) == true)

        let restFont = rendered.attribute(.font, at: 4, effectiveRange: nil) as? NSFont
        #expect(restFont?.fontDescriptor.symbolicTraits.contains(.bold) == false)
    }

    @Test("L'italique applique le trait .italic a la police")
    func italicAppliesFontTrait() {
        var text = RichText(plainText: "Bonjour")
        text.apply(.italic, to: text.range(charactersOffset: 0..<7))
        let rendered = render(text)

        let font = rendered.attribute(.font, at: 0, effectiveRange: nil) as? NSFont
        #expect(font?.fontDescriptor.symbolicTraits.contains(.italic) == true)
    }

    @Test("Gras + italique cumules donnent bien les DEUX traits sur la meme police")
    func boldAndItalicCumulateOnSameFont() {
        var text = RichText(plainText: "Bonjour")
        let range = text.range(charactersOffset: 0..<7)
        text.apply(.bold, to: range)
        text.apply(.italic, to: range)
        let rendered = render(text)

        let font = rendered.attribute(.font, at: 0, effectiveRange: nil) as? NSFont
        #expect(font?.fontDescriptor.symbolicTraits.contains(.bold) == true)
        #expect(font?.fontDescriptor.symbolicTraits.contains(.italic) == true)
    }

    @Test("Le code inline bascule sur une police a chasse fixe, avec fond/texte dedies")
    func inlineCodeUsesMonospacedFontAndColors() {
        var text = RichText(plainText: "let x = 1")
        text.apply(.inlineCode, to: text.range(charactersOffset: 0..<3))
        let rendered = render(text)

        let font = rendered.attribute(.font, at: 0, effectiveRange: nil) as? NSFont
        #expect(font?.fontDescriptor.symbolicTraits.contains(.monoSpace) == true)
        #expect(rendered.attribute(.backgroundColor, at: 0, effectiveRange: nil) != nil)
        #expect(rendered.attribute(.foregroundColor, at: 0, effectiveRange: nil) != nil)
    }

    @Test("Le souligne pose bien .underlineStyle simple")
    func underlineAppliesUnderlineStyle() {
        var text = RichText(plainText: "Bonjour")
        text.apply(.underline, to: text.range(charactersOffset: 0..<7))
        let rendered = render(text)

        let style = rendered.attribute(.underlineStyle, at: 0, effectiveRange: nil) as? Int
        #expect(style == NSUnderlineStyle.single.rawValue)
    }

    @Test("Le barre pose .strikethroughStyle SANS forcer de couleur dediee")
    func strikethroughAppliesStrikethroughStyleWithoutColorOverride() {
        var text = RichText(plainText: "Bonjour")
        text.apply(.strikethrough, to: text.range(charactersOffset: 0..<7))
        let rendered = render(text)

        let style = rendered.attribute(.strikethroughStyle, at: 0, effectiveRange: nil) as? Int
        #expect(style == NSUnderlineStyle.single.rawValue)
        #expect(rendered.attribute(.strikethroughColor, at: 0, effectiveRange: nil) == nil)
    }

    /// Chasse le piege signale a la revue de phase 7 : l'identifiant ecrit par
    /// `FormatColorPopoverView`/`SlateHighlightColor.value` (`SlateHighlightToken.rawValue`,
    /// ex: "yellow") doit resoudre en la MEME couleur que `SlateHighlightToken.yellow.
    /// background` -- si les deux cotes du pont divergent, le surlignage reste stocke
    /// mais se rend incolore, sans aucune erreur (voir le rapport de revue).
    @Test(
        "Chaque token de surlignage se rend avec la couleur EXACTE de son token SlateUI",
        arguments: SlateHighlightToken.allCases
    )
    func highlightRendersExactTokenColor(token: SlateHighlightToken) throws {
        var text = RichText(plainText: "Bonjour")
        text.apply(.highlight(SlateHighlightColor(token.rawValue)), to: text.range(charactersOffset: 0..<7))
        let rendered = render(text)

        let renderedColor = try #require(rendered.attribute(.backgroundColor, at: 0, effectiveRange: nil) as? NSColor)
        try expectSameColor(renderedColor, NSColor(token.background))
    }

    /// Symmetrique de ci-dessus pour la couleur de texte.
    @Test(
        "Chaque token de couleur de texte se rend avec la couleur EXACTE de son token SlateUI",
        arguments: SlateTextColorToken.allCases
    )
    func textColorRendersExactTokenColor(token: SlateTextColorToken) throws {
        var text = RichText(plainText: "Bonjour")
        text.apply(.textColor(SlateTextColor(token.rawValue)), to: text.range(charactersOffset: 0..<7))
        let rendered = render(text)

        let renderedColor = try #require(rendered.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor)
        try expectSameColor(renderedColor, NSColor(token.foreground))
    }

    @Test("Un identifiant de surlignage INCONNU (ex: une couleur hex) n'ajoute aucun fond, sans crash")
    func unknownHighlightIdentifierAddsNoBackground() {
        var text = RichText(plainText: "Bonjour")
        text.apply(.highlight(SlateHighlightColor("#ABCDEF")), to: text.range(charactersOffset: 0..<7))
        let rendered = render(text)

        #expect(rendered.attribute(.backgroundColor, at: 0, effectiveRange: nil) == nil)
    }

    @Test("Un lien pose un soulignement PERMANENT et la couleur text.link")
    func linkAppliesPermanentUnderlineAndLinkColor() throws {
        var text = RichText(plainText: "Bonjour")
        text.apply(.link(URL(fileURLWithPath: "/tmp")), to: text.range(charactersOffset: 0..<7))
        let rendered = render(text)

        let style = rendered.attribute(.underlineStyle, at: 0, effectiveRange: nil) as? Int
        #expect(style == NSUnderlineStyle.single.rawValue)
        let color = try #require(rendered.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor)
        try expectSameColor(color, NSColor(SlateColor.textLink))
    }

    @Test("Le code inline prend le pas sur le fond de surlignage (le fond code reste visible)")
    func inlineCodeTakesPrecedenceOverHighlightBackground() throws {
        var text = RichText(plainText: "Bonjour")
        let range = text.range(charactersOffset: 0..<7)
        text.apply(.highlight(SlateHighlightColor("yellow")), to: range)
        text.apply(.inlineCode, to: range)
        let rendered = render(text)

        let background = try #require(rendered.attribute(.backgroundColor, at: 0, effectiveRange: nil) as? NSColor)
        try expectSameColor(background, NSColor(SlateColor.codeInlineBackground))
    }
}
