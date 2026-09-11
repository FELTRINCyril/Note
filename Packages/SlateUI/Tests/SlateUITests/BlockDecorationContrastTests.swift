import Testing
@testable import SlateUI

/// Verifie par calcul les contrastes WCAG 2.1 des blocs decores ajoutes en Phase 8
/// (design/tokens.md §16 bis/ter, artboards E/F de
/// `Slate P1 - Formatage & blocs.dc.html`). Meme motif que
/// `InlineFormattingContrastTests` : on ne suppose jamais qu'un aplat pastel ou une
/// teinte de coloration syntaxique reste lisible, on la mesure.
@Suite("Contraste WCAG 2.1 - callouts (design/tokens.md §16 bis)")
struct CalloutContrastTests {
    private static let textPrimaryLight = SlateRGB(red: 0, green: 0, blue: 0, alpha: 0.85)
    private static let textPrimaryDark = SlateRGB(red: 1, green: 1, blue: 1, alpha: 0.85)

    @Test(
        "text.primary sur chaque fond de callout clair atteint au moins l'AA (4,5:1)",
        arguments: SlateCalloutVariant.allCases
    )
    func textPrimaryOnCalloutBackgroundMeetsAAInLight(variant: SlateCalloutVariant) {
        let composited = WCAGContrast.compositeOverBackground(Self.textPrimaryLight, variant.backgroundLightRGB)
        let ratio = WCAGContrast.ratio(composited, variant.backgroundLightRGB)

        #expect(ratio >= 4.5)
    }

    @Test(
        "text.primary sur chaque fond de callout sombre atteint au moins l'AA (4,5:1)",
        arguments: SlateCalloutVariant.allCases
    )
    func textPrimaryOnCalloutBackgroundMeetsAAInDark(variant: SlateCalloutVariant) {
        let composited = WCAGContrast.compositeOverBackground(Self.textPrimaryDark, variant.backgroundDarkRGB)
        let ratio = WCAGContrast.ratio(composited, variant.backgroundDarkRGB)

        #expect(ratio >= 4.5)
    }

    @Test(
        "La couleur de libelle de chaque variante tient l'AA sur son propre fond, en clair",
        arguments: SlateCalloutVariant.allCases
    )
    func labelColorOnOwnBackgroundMeetsAAInLight(variant: SlateCalloutVariant) {
        let ratio = WCAGContrast.ratio(variant.labelLightRGB, variant.backgroundLightRGB)

        #expect(ratio >= 4.5)
    }

    @Test(
        "La couleur de libelle de chaque variante tient l'AA sur son propre fond, en sombre",
        arguments: SlateCalloutVariant.allCases
    )
    func labelColorOnOwnBackgroundMeetsAAInDark(variant: SlateCalloutVariant) {
        let ratio = WCAGContrast.ratio(variant.labelDarkRGB, variant.backgroundDarkRGB)

        #expect(ratio >= 4.5)
    }
}

@Suite("Contraste WCAG 2.1 - coloration syntaxique (design/tokens.md §16 ter)")
struct CodeSyntaxContrastTests {
    private static let codeBlockBgLight = SlateRGB(hex: "#F5F5F7") ?? .white
    private static let codeBlockBgDark = SlateRGB(hex: "#2A2A2C") ?? .black

    @Test(
        "Chaque role code.syntax.* tient l'AA sur code.block.bg clair",
        arguments: SlateSyntaxToken.allCases
    )
    func syntaxTokenMeetsAAOnCodeBlockBackgroundInLight(token: SlateSyntaxToken) {
        let composited = WCAGContrast.compositeOverBackground(token.lightRGB, Self.codeBlockBgLight)
        let ratio = WCAGContrast.ratio(composited, Self.codeBlockBgLight)

        #expect(ratio >= 4.5)
    }

    @Test(
        "Chaque role code.syntax.* tient l'AA sur code.block.bg sombre",
        arguments: SlateSyntaxToken.allCases
    )
    func syntaxTokenMeetsAAOnCodeBlockBackgroundInDark(token: SlateSyntaxToken) {
        let composited = WCAGContrast.compositeOverBackground(token.darkRGB, Self.codeBlockBgDark)
        let ratio = WCAGContrast.ratio(composited, Self.codeBlockBgDark)

        #expect(ratio >= 4.5)
    }
}

@Suite("Contraste WCAG 2.1 - citation (design/tokens.md §16)")
struct QuoteContrastTests {
    /// `quote.text` est un noir/blanc translucide (65 %) pose EN TEXTE sur `bg.editor` :
    /// il doit etre compose avant d'etre mesure, comme le texte translucide de
    /// `ContrastRatio.swift`.
    @Test("quote.text tient l'AA sur bg.editor, en clair comme en sombre")
    func quoteTextMeetsAAOnEditorBackground() {
        let bgEditorLight = SlateRGB(hex: "#FFFFFF") ?? .white
        let bgEditorDark = SlateRGB(hex: "#1C1C1E") ?? .black
        let quoteTextLight = SlateRGB(red: 0, green: 0, blue: 0, alpha: 0.65)
        let quoteTextDark = SlateRGB(red: 1, green: 1, blue: 1, alpha: 0.65)

        let lightComposited = WCAGContrast.compositeOverBackground(quoteTextLight, bgEditorLight)
        let darkComposited = WCAGContrast.compositeOverBackground(quoteTextDark, bgEditorDark)

        #expect(WCAGContrast.ratio(lightComposited, bgEditorLight) >= 4.5)
        #expect(WCAGContrast.ratio(darkComposited, bgEditorDark) >= 4.5)
    }
}
