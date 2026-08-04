import Testing
@testable import SlateUI

/// Verification par calcul des chiffres de contraste annonces par la spec E4
/// (`design/05_editeur/.../Slate E4 - Editeur.dc.html`, sections "Mesure de contraste"
/// et "Accessibilite"). Meme demarche que `ContrastRatioTests`/`NoteListContrastTests`
/// (Phases 2-4) : la spec s'est deja trompee deux fois sur ce projet, on ne la croit
/// jamais sur parole, on recalcule.
///
/// Ces tests lisent des `SlateRGB` bruts (`SlateBlockSelection`, `SlateTextOpacity`),
/// jamais les `Color` calculees de `SlateColor` : celles-ci lisent
/// `SlateAccessibility.shared` via `MainActor.assumeIsolated` (voir
/// `SlateAccessibility.swift`), et Swift Testing ne garantit pas l'execution sur le
/// thread principal.
@Suite("Accessibilite de l'editeur (spec E4)")
struct EditorAccessibilityTests {
    private static let bgEditorLight = SlateRGB(hex: "#FFFFFF") ?? .white
    private static let bgEditorDark = SlateRGB(hex: "#1C1C1E") ?? .black
    private static let textPrimaryLight = SlateRGB(red: 0, green: 0, blue: 0, alpha: 0.85)
    private static let textPrimaryDark = SlateRGB(red: 1, green: 1, blue: 1, alpha: 0.85)

    // MARK: - Contour de focus clavier (translucide) + lisere opaque de renfort

    @Test(
        "La spec E4 annonce 3,08:1 pour le contour de focus clair sur bg.editor : en realite ~2,29:1, SOUS 3:1"
    )
    func focusRingTranslucentFailsNonTextMinimumInLight() {
        let focusRing = SlateRGB(red: 0, green: 122.0 / 255, blue: 255.0 / 255, alpha: 0.60)
        let composited = WCAGContrast.compositeOverBackground(focusRing, Self.bgEditorLight)
        let ratio = WCAGContrast.ratio(composited, Self.bgEditorLight)

        #expect(abs(ratio - 2.29) < 0.05)
        // La spec pretend "3,08:1, juste au-dessus du minimum 3:1" : la valeur reelle
        // est sous ce minimum, pas juste au-dessus.
        #expect(ratio < 3.0)
    }

    @Test(
        "La spec E4 annonce 3,21:1 pour le contour de focus sombre sur bg.editor : en realite ~2,68:1, SOUS 3:1"
    )
    func focusRingTranslucentFailsNonTextMinimumInDark() {
        let focusRing = SlateRGB(red: 10.0 / 255, green: 132.0 / 255, blue: 255.0 / 255, alpha: 0.65)
        let composited = WCAGContrast.compositeOverBackground(focusRing, Self.bgEditorDark)
        let ratio = WCAGContrast.ratio(composited, Self.bgEditorDark)

        #expect(abs(ratio - 2.68) < 0.05)
        #expect(ratio < 3.0)
    }

    @Test("Le lisere opaque de renfort (accent.default plein) atteint bien le minimum 3:1 non textuel, en clair")
    func opaqueReinforcementMeetsNonTextMinimumInLight() {
        let ratio = WCAGContrast.ratio(SlateAccent.defaultLightRGB, Self.bgEditorLight)
        #expect(ratio >= 3.0)
        #expect(abs(ratio - 4.02) < 0.05)
    }

    @Test("Le lisere opaque de renfort atteint bien le minimum 3:1 non textuel, en sombre")
    func opaqueReinforcementMeetsNonTextMinimumInDark() {
        let ratio = WCAGContrast.ratio(SlateAccent.defaultDarkRGB, Self.bgEditorDark)
        #expect(ratio >= 3.0)
        #expect(abs(ratio - 4.66) < 0.05)
    }

    // MARK: - Texte sur l'aplat de bloc selectionne (block.selected.bg)

    @Test("Texte sur block.selected.bg en clair : spec 12,4:1, mesure reelle ~13,4:1 (les deux depassent l'AAA)")
    func textOnSelectedBlockBackgroundInLight() {
        let backgroundOverEditor = WCAGContrast.compositeOverBackground(
            SlateBlockSelection.backgroundLightRGB,
            Self.bgEditorLight
        )
        let textOverBackground = WCAGContrast.compositeOverBackground(Self.textPrimaryLight, backgroundOverEditor)
        let ratio = WCAGContrast.ratio(textOverBackground, backgroundOverEditor)

        #expect(abs(ratio - 13.4) < 0.2)
        #expect(ratio >= 7.0)
    }

    @Test("Texte sur block.selected.bg en sombre : la spec annonce 9,6:1, la mesure reelle donne ~10,0:1")
    func textOnSelectedBlockBackgroundInDark() {
        let backgroundOverEditor = WCAGContrast.compositeOverBackground(
            SlateBlockSelection.backgroundDarkRGB,
            Self.bgEditorDark
        )
        let textOverBackground = WCAGContrast.compositeOverBackground(Self.textPrimaryDark, backgroundOverEditor)
        let ratio = WCAGContrast.ratio(textOverBackground, backgroundOverEditor)

        #expect(abs(ratio - 10.0) < 0.2)
        #expect(ratio >= 7.0)
    }

    // MARK: - Increase Contrast : block.selected.bg passe de 12/20 % a 22/32 %

    @Test("Increase Contrast : block.selected.bg clair passe bien de 12 % a 22 %")
    func selectedBlockBackgroundIncreasedContrastAlphaInLight() {
        #expect(SlateBlockSelection.backgroundLightRGB.alpha == 0.12)
        #expect(SlateBlockSelection.backgroundLightIncreasedContrastRGB.alpha == 0.22)
    }

    @Test("Increase Contrast : block.selected.bg sombre passe bien de 20 % a 32 %")
    func selectedBlockBackgroundIncreasedContrastAlphaInDark() {
        #expect(SlateBlockSelection.backgroundDarkRGB.alpha == 0.20)
        #expect(SlateBlockSelection.backgroundDarkIncreasedContrastRGB.alpha == 0.32)
    }

    @Test("Increase Contrast : le texte sur l'aplat renforce (22 %/32 %) reste tres au-dessus de l'AAA")
    func textOnIncreasedContrastSelectedBlockBackground() {
        let lightBackground = WCAGContrast.compositeOverBackground(
            SlateBlockSelection.backgroundLightIncreasedContrastRGB,
            Self.bgEditorLight
        )
        let lightText = WCAGContrast.compositeOverBackground(Self.textPrimaryLight, lightBackground)
        #expect(WCAGContrast.ratio(lightText, lightBackground) >= 7.0)

        let darkBackground = WCAGContrast.compositeOverBackground(
            SlateBlockSelection.backgroundDarkIncreasedContrastRGB,
            Self.bgEditorDark
        )
        let darkText = WCAGContrast.compositeOverBackground(Self.textPrimaryDark, darkBackground)
        #expect(WCAGContrast.ratio(darkText, darkBackground) >= 7.0)
    }

    // MARK: - Placeholder en Increase Contrast (text.placeholder a 0,54/0,58)

    @Test("Les opacites du placeholder Increase Contrast sont bien 0,54 (clair) et 0,58 (sombre)")
    func placeholderIncreasedContrastOpacities() {
        #expect(SlateTextOpacity.placeholderLightIncreasedContrast == 0.54)
        #expect(SlateTextOpacity.placeholderDarkIncreasedContrast == 0.58)
        #expect(SlateTextOpacity.placeholderLight == 0.25)
        #expect(SlateTextOpacity.placeholderDark == 0.25)
    }

    /// La spec E4 ecrit l'opacite "0,52" mais annonce l'objectif "4,6:1" dans la meme
    /// phrase. 0,52 ne donne que 4,27:1, donc rate l'AA ET rate l'objectif annonce :
    /// c'est le chiffre de la spec qui est faux, pas son intention. On applique 0,54,
    /// qui donne 4,59:1, soit exactement la valeur annoncee. Ce test verrouille
    /// l'objectif AA, pas la constante : il echouerait si quelqu'un remettait 0,52.
    @Test("Le placeholder Increase Contrast atteint l'AA en clair, ~4,59:1 (objectif annonce par la spec)")
    func placeholderIncreasedContrastMeetsAAInLight() {
        let placeholder = SlateRGB(red: 0, green: 0, blue: 0, alpha: SlateTextOpacity.placeholderLightIncreasedContrast)
        let composited = WCAGContrast.compositeOverBackground(placeholder, Self.bgEditorLight)
        let ratio = WCAGContrast.ratio(composited, Self.bgEditorLight)

        #expect(abs(ratio - 4.59) < 0.05)
        #expect(ratio >= 4.5)
    }

    /// Contre-preuve du test precedent : la valeur litterale de la spec echoue bien.
    /// Documente pourquoi on s'en ecarte, pour qu'un futur relecteur ne "corrige" pas
    /// 0,54 en 0,52 en croyant revenir a la spec.
    @Test("La valeur litterale 0,52 de la spec E4 echouerait l'AA en clair (~4,27:1)")
    func specLiteralPlaceholderOpacityWouldFailAAInLight() {
        let placeholder = SlateRGB(red: 0, green: 0, blue: 0, alpha: 0.52)
        let composited = WCAGContrast.compositeOverBackground(placeholder, Self.bgEditorLight)
        let ratio = WCAGContrast.ratio(composited, Self.bgEditorLight)

        #expect(abs(ratio - 4.27) < 0.05)
        #expect(ratio < 4.5)
    }

    @Test("Le placeholder Increase Contrast atteint bien l'AA en sombre : ~6,48:1")
    func placeholderIncreasedContrastMeetsAAInDark() {
        let placeholder = SlateRGB(red: 1, green: 1, blue: 1, alpha: SlateTextOpacity.placeholderDarkIncreasedContrast)
        let composited = WCAGContrast.compositeOverBackground(placeholder, Self.bgEditorDark)
        let ratio = WCAGContrast.ratio(composited, Self.bgEditorDark)

        #expect(abs(ratio - 6.48) < 0.05)
        #expect(ratio >= 4.5)
    }

    @Test("Hors Increase Contrast, le placeholder (0,25) reste loin de l'AA -- attendu, il n'est pas porteur d'info")
    func placeholderBaseOpacityIsFarFromAA() {
        let placeholder = SlateRGB(red: 0, green: 0, blue: 0, alpha: SlateTextOpacity.placeholderLight)
        let composited = WCAGContrast.compositeOverBackground(placeholder, Self.bgEditorLight)
        let ratio = WCAGContrast.ratio(composited, Self.bgEditorLight)

        #expect(ratio < 4.5)
    }

    // MARK: - Geometrie (verifiable sans acceder a une Color / MainActor)

    @Test("La gouttiere de l'editeur vaut bien 48 pt = 2 x handle.size + space.xs + space.s")
    func editorGutterFormula() {
        let gutterFromFormula = SlateGeometry.blockHandleSize * 2 + Spacing.xs + Spacing.sm
        #expect(abs(SlateGeometry.editorGutter - gutterFromFormula) < 0.001)
        #expect(abs(SlateGeometry.editorGutter - 48) < 0.001)
    }

    @Test("La colonne de texte n'est jamais reduite pour faire tenir la gouttiere dedans")
    func maxContentWidthStaysAt720() {
        #expect(SlateGeometry.editorMaxContentWidth == 720)
    }
}
