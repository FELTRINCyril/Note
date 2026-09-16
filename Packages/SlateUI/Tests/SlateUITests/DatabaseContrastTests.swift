import Testing
@testable import SlateUI

/// Verifie par calcul les contrastes WCAG 2.1 des nouvelles couleurs de la Phase 17
/// (design/tokens.md §18, `Slate P5 - Bases de donnees.dc.html`) : texte sur en-tete de
/// colonne, sur carte Kanban, sur pastille de statut/etiquette (par accent), ligne
/// alternee. Meme motif que `BlockDecorationContrastTests.swift` : on mesure, on ne
/// suppose jamais.
@Suite("Contraste WCAG 2.1 - base de donnees (design/tokens.md §18)")
struct DatabaseContrastTests {
    private static let textPrimaryLight = SlateRGB(red: 0, green: 0, blue: 0, alpha: 0.85)
    private static let textPrimaryDark = SlateRGB(red: 1, green: 1, blue: 1, alpha: 0.85)

    private static let gridHeaderBgLight = SlateRGB(hex: "#F2F2F5") ?? .white
    private static let gridHeaderBgDark = SlateRGB(hex: "#2C2C2E") ?? .black

    private static let cardBgLight = SlateRGB(hex: "#FFFFFF") ?? .white
    private static let cardBgDark = SlateRGB(hex: "#2A2A2C") ?? .black

    @Test("text.primary sur db.grid.headerBg tient l'AA, clair")
    func textPrimaryOnGridHeaderMeetsAAInLight() {
        let composited = WCAGContrast.compositeOverBackground(Self.textPrimaryLight, Self.gridHeaderBgLight)
        #expect(WCAGContrast.ratio(composited, Self.gridHeaderBgLight) >= 4.5)
    }

    @Test("text.primary sur db.grid.headerBg tient l'AA, sombre")
    func textPrimaryOnGridHeaderMeetsAAInDark() {
        let composited = WCAGContrast.compositeOverBackground(Self.textPrimaryDark, Self.gridHeaderBgDark)
        #expect(WCAGContrast.ratio(composited, Self.gridHeaderBgDark) >= 4.5)
    }

    @Test("text.primary sur db.card.bg (Kanban/Galerie) tient l'AA, clair")
    func textPrimaryOnCardMeetsAAInLight() {
        let composited = WCAGContrast.compositeOverBackground(Self.textPrimaryLight, Self.cardBgLight)
        #expect(WCAGContrast.ratio(composited, Self.cardBgLight) >= 4.5)
    }

    @Test("text.primary sur db.card.bg (Kanban/Galerie) tient l'AA, sombre")
    func textPrimaryOnCardMeetsAAInDark() {
        let composited = WCAGContrast.compositeOverBackground(Self.textPrimaryDark, Self.cardBgDark)
        #expect(WCAGContrast.ratio(composited, Self.cardBgDark) >= 4.5)
    }

    /// `accent.subtle` est TRANSLUCIDE (§3 : alpha 0,12 clair / 0,22 sombre) : mesurer
    /// honnetement le libelle depose dessus exige de d'abord composer ce fond sur un
    /// arriere-plan REEL (`bg.editor`, meme repere que `SlateAccentColor.pillLabelRGB`),
    /// puis le libelle (opaque) sur ce fond desormais opaque -- jamais `ratio()`
    /// directement sur une couleur alpha, qui ignorerait le canal alpha et
    /// sur-estimerait le contraste.
    @Test(
        "Le libelle d'une pastille (SlateAccentColor.pillLabelRGB) tient l'AA sur son fond, clair",
        arguments: SlateAccentColor.allCases
    )
    func pillLabelOnSubtleBackgroundMeetsAAInLight(accent: SlateAccentColor) {
        let backdrop = SlateRGB(hex: "#FFFFFF") ?? .white
        let background = WCAGContrast.compositeOverBackground(accent.subtleRGB(dark: false), backdrop)
        #expect(WCAGContrast.ratio(accent.pillLabelRGB(dark: false), background) >= 4.5)
    }

    @Test(
        "Le libelle d'une pastille (SlateAccentColor.pillLabelRGB) tient l'AA sur son fond, sombre",
        arguments: SlateAccentColor.allCases
    )
    func pillLabelOnSubtleBackgroundMeetsAAInDark(accent: SlateAccentColor) {
        let backdrop = SlateRGB(hex: "#1C1C1E") ?? .black
        let background = WCAGContrast.compositeOverBackground(accent.subtleRGB(dark: true), backdrop)
        #expect(WCAGContrast.ratio(accent.pillLabelRGB(dark: true), background) >= 4.5)
    }

    @Test("Le libelle neutre (db.tag, sans accent) tient l'AA sur son propre fond, clair")
    func neutralPillLabelMeetsAAInLight() {
        let background = WCAGContrast.compositeOverBackground(
            SlateRGB(red: 0, green: 0, blue: 0, alpha: 0.06),
            Self.cardBgLight
        )
        let label = SlateRGB(hex: "#5A626B") ?? .black
        #expect(WCAGContrast.ratio(label, background) >= 4.5)
    }

    @Test("Le libelle neutre (db.tag, sans accent) tient l'AA sur son propre fond, sombre")
    func neutralPillLabelMeetsAAInDark() {
        let background = WCAGContrast.compositeOverBackground(
            SlateRGB(red: 1, green: 1, blue: 1, alpha: 0.10),
            Self.cardBgDark
        )
        let label = SlateRGB(hex: "#A8B0B8") ?? .white
        #expect(WCAGContrast.ratio(label, background) >= 4.5)
    }

    @Test("text.primary sur table.rowStripe (ligne alternee) tient l'AA, clair")
    func textPrimaryOnRowStripeMeetsAAInLight() {
        let stripe = SlateRGB(red: 0, green: 0, blue: 0, alpha: 0.02)
        let base = SlateRGB(hex: "#FFFFFF") ?? .white
        let compositedBg = WCAGContrast.compositeOverBackground(stripe, base)
        let compositedText = WCAGContrast.compositeOverBackground(Self.textPrimaryLight, compositedBg)
        #expect(WCAGContrast.ratio(compositedText, compositedBg) >= 4.5)
    }

    @Test("text.primary sur table.rowStripe (ligne alternee) tient l'AA, sombre")
    func textPrimaryOnRowStripeMeetsAAInDark() {
        let stripe = SlateRGB(red: 1, green: 1, blue: 1, alpha: 0.03)
        let base = SlateRGB(hex: "#1C1C1E") ?? .black
        let compositedBg = WCAGContrast.compositeOverBackground(stripe, base)
        let compositedText = WCAGContrast.compositeOverBackground(Self.textPrimaryDark, compositedBg)
        #expect(WCAGContrast.ratio(compositedText, compositedBg) >= 4.5)
    }
}
