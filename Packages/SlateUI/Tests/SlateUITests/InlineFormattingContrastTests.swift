import Testing
@testable import SlateUI

/// Verifie par calcul que `text.primary` (le texte pose par-dessus un surlignage,
/// artboard `design/_design_complet/Slate P1 - Formatage & blocs.dc.html`, section B :
/// "texte = text.primary par-dessus") reste lisible sur les 6 aplats de surlignage de
/// design/tokens.md §6, dans les deux themes. Seule categorie de test demandee pour la
/// Phase 7 (typographie & formatage) : c'est un chemin critique d'accessibilite, comme
/// `EditorAccessibilityTests`/`ContrastRatioTests` pour les phases precedentes -- on ne
/// suppose jamais qu'un aplat pastel reste lisible, on le mesure.
@Suite("Contraste WCAG 2.1 - surlignage inline (design/tokens.md §6)")
struct InlineFormattingContrastTests {
    private static let textPrimaryLight = SlateRGB(red: 0, green: 0, blue: 0, alpha: 0.85)
    private static let textPrimaryDark = SlateRGB(red: 1, green: 1, blue: 1, alpha: 0.85)

    @Test(
        "text.primary sur chaque aplat de surlignage clair atteint au moins l'AA (4,5:1)",
        arguments: SlateHighlightToken.allCases
    )
    func textPrimaryOnHighlightMeetsAAInLight(highlight: SlateHighlightToken) {
        let composited = WCAGContrast.compositeOverBackground(Self.textPrimaryLight, highlight.lightRGB)
        let ratio = WCAGContrast.ratio(composited, highlight.lightRGB)

        #expect(ratio >= 4.5)
    }

    @Test(
        "text.primary sur chaque aplat de surlignage sombre atteint au moins l'AA (4,5:1)",
        arguments: SlateHighlightToken.allCases
    )
    func textPrimaryOnHighlightMeetsAAInDark(highlight: SlateHighlightToken) {
        let composited = WCAGContrast.compositeOverBackground(Self.textPrimaryDark, highlight.darkRGB)
        let ratio = WCAGContrast.ratio(composited, highlight.darkRGB)

        #expect(ratio >= 4.5)
    }

    @Test("Les 6 tokens de surlignage clair/sombre restent bien confortablement au-dessus de l'AAA (7:1)")
    func highlightsComfortablyExceedAAA() {
        for highlight in SlateHighlightToken.allCases {
            let lightComposited = WCAGContrast.compositeOverBackground(Self.textPrimaryLight, highlight.lightRGB)
            #expect(WCAGContrast.ratio(lightComposited, highlight.lightRGB) >= 7.0)

            let darkComposited = WCAGContrast.compositeOverBackground(Self.textPrimaryDark, highlight.darkRGB)
            #expect(WCAGContrast.ratio(darkComposited, highlight.darkRGB) >= 7.0)
        }
    }
}

// MARK: - Lien et actions destructives (design/tokens.md §2 et §4)

@Suite("Contraste des liens et des actions destructives")
struct LinkAndDestructiveContrastTests {
    /// `text.link` est pose EN TEXTE sur le fond de l'editeur : il doit tenir l'AA (4,5:1).
    /// C'est precisement le piege signale par la note de `tokens.md` §7, ou l'accent brut
    /// tombe parfois a 2,0:1.
    @Test("text.link tient l'AA sur bg.editor, en clair comme en sombre")
    func textLinkMeetsAAOnEditorBackground() {
        let lightRatio = WCAGContrast.ratio(
            SlateRGB(hex: "#0A66C2") ?? .black,
            SlateRGB(hex: "#FFFFFF") ?? .white
        )
        let darkRatio = WCAGContrast.ratio(
            SlateRGB(hex: "#6CB6FF") ?? .black,
            SlateRGB(hex: "#1E1E1E") ?? .black
        )
        #expect(lightRatio >= 4.5)
        #expect(darkRatio >= 4.5)
    }

    /// L'aplat de bouton destructif porte du texte blanc : c'est la raison d'etre de la
    /// variante `semanticErrorFill` (#C4271E) face a `semanticError` (#FF3B30, 3,94:1).
    @Test("Le blanc sur semanticErrorFill tient l'AA, contrairement a semanticError brut")
    func destructiveFillMeetsAAWithWhiteText() {
        let fillRatio = WCAGContrast.ratio(
            SlateRGB(hex: "#FFFFFF") ?? .white,
            SlateRGB(hex: "#C4271E") ?? .black
        )
        let rawRatio = WCAGContrast.ratio(
            SlateRGB(hex: "#FFFFFF") ?? .white,
            SlateRGB(hex: "#FF3B30") ?? .black
        )
        #expect(fillRatio >= 4.5)
        #expect(rawRatio < 4.5)
    }
}
