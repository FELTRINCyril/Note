import Testing
@testable import SlateUI

/// Tests du defaut REEL trouve en revue de phase 4 dans la regle de contraste heritee de
/// la phase 3 : `WCAGContrast.darkening` mesurait `ratio(label, candidate)` directement,
/// sans composer l'alpha de `label` sur `candidate` avant de mesurer. Pour un `label`
/// opaque (l'usage de la phase 3) c'etait sans consequence, mais la spec E3 introduit un
/// premier plan SECONDAIRE translucide (l'extrait de la cellule, blanc 95%) qui doit
/// aussi respecter l'AA sur le meme aplat : la regle ciblait implicitement le premier
/// plan LE PLUS FACILE (blanc opaque) au lieu du plus EXIGEANT (blanc 95%).
///
/// Voir la documentation complete dans `ContrastRatio.swift` ("le piege corrige") et
/// `SlateColor.swift` (`SlateAccent.selectionForegroundSecondary`).
@Suite("Contraste WCAG 2.1 - phase 4 (defaut de la regle de darkening)")
struct NoteListContrastTests {
    /// Blanc a 95% d'opacite : le premier plan secondaire exact de la spec E3.
    private static let white95 = SlateRGB(red: 1, green: 1, blue: 1, alpha: 0.95)

    @Test("Defaut encode : blanc 95% sur l'ANCIEN aplat (#0071ED, cible = blanc opaque) echoue l'AA")
    func white95OnOldFillFailsAA() throws {
        // #0071ED : resultat de l'ancienne regle de phase 3, qui assombrissait #007AFF
        // jusqu'a ce que le blanc OPAQUE atteigne 4,5:1 (~4,58:1), sans jamais verifier
        // le blanc 95% reellement pose sur l'aplat par l'extrait de la cellule.
        let oldFill = try requireRGB("#0071ED")
        let composited = WCAGContrast.compositeOverBackground(Self.white95, oldFill)
        let ratio = WCAGContrast.ratio(composited, oldFill)

        #expect(abs(ratio - 4.28) < 0.05)
        #expect(ratio < 4.5)
    }

    @Test("Correctif : blanc 95% sur le NOUVEL aplat clair atteint bien l'AA (>= 4,5:1)")
    func white95OnNewFillMeetsAAInLight() {
        let newFill = SlateAccent.selectionFillLightRGB
        let composited = WCAGContrast.compositeOverBackground(Self.white95, newFill)
        let ratio = WCAGContrast.ratio(composited, newFill)

        #expect(ratio >= 4.5)
    }

    @Test("Correctif : blanc 95% sur le NOUVEL aplat sombre atteint bien l'AA (>= 4,5:1)")
    func white95OnNewFillMeetsAAInDark() {
        let newFill = SlateAccent.selectionFillDarkRGB
        let composited = WCAGContrast.compositeOverBackground(Self.white95, newFill)
        let ratio = WCAGContrast.ratio(composited, newFill)

        #expect(ratio >= 4.5)
    }

    @Test("Le premier plan PRINCIPAL (blanc opaque) reste >= 4,5:1 sur le nouvel aplat clair")
    func opaqueWhiteStillMeetsAAOnNewFillInLight() {
        let ratio = WCAGContrast.ratio(.white, SlateAccent.selectionFillLightRGB)
        #expect(ratio >= 4.5)
    }

    @Test("Le premier plan PRINCIPAL (blanc opaque) reste >= 4,5:1 sur le nouvel aplat sombre")
    func opaqueWhiteStillMeetsAAOnNewFillInDark() {
        let ratio = WCAGContrast.ratio(.white, SlateAccent.selectionFillDarkRGB)
        #expect(ratio >= 4.5)
    }

    @Test("Le nouvel aplat reste plus sombre que l'accent par defaut, dans les deux themes")
    func newFillIsDarkerThanDefaultAccent() {
        // `.red` vaut 0 pour #007AFF/#0A84FF (aucune composante rouge) : comparer la
        // luminance relative plutot qu'une composante isolee, generale pour tout accent.
        #expect(
            WCAGContrast.relativeLuminance(SlateAccent.selectionFillLightRGB)
                < WCAGContrast.relativeLuminance(SlateAccent.defaultLightRGB)
        )
        #expect(
            WCAGContrast.relativeLuminance(SlateAccent.selectionFillDarkRGB)
                < WCAGContrast.relativeLuminance(SlateAccent.defaultDarkRGB)
        )
    }

    @Test("La regle generalisee choisit du texte sombre sur un accent clair type jaune (#FFCC00), alpha aplati")
    func chooseDarkTextOnLightAccentWithFlattenedAlpha() throws {
        let yellow = try requireRGB("#FFCC00")
        // La spec E3 (Accessibilite) : "Accent jaune -> texte noir 88%". La regle
        // generale choisit d'abord le libelle opaque le plus contraste (`labelColor`)...
        #expect(WCAGContrast.labelColor(on: yellow) == .black)

        // ...puis, meme avec l'alpha REELLEMENT annonce par la spec (noir 88%, pas noir
        // opaque), l'alpha aplati sur le fond jaune doit satisfaire au moins l'AA "large
        // texte" (3:1) -- verifie ici en le composant explicitement, comme le ferait la
        // regle de darkening pour un accent personnalise clair.
        let black88 = SlateRGB(red: 0, green: 0, blue: 0, alpha: 0.88)
        let composited = WCAGContrast.compositeOverBackground(black88, yellow)
        let ratio = WCAGContrast.ratio(composited, yellow)

        #expect(ratio >= 4.5)
    }

    // MARK: - Increase Contrast

    @Test("Increase Contrast : la cible passe a 7:1 et l'aplat clair obtenu l'atteint reellement (blanc 95%)")
    func increasedContrastFillMeets7to1InLight() {
        let fill = SlateAccent.selectionFillLightRGBIncreasedContrast
        let composited = WCAGContrast.compositeOverBackground(Self.white95, fill)
        let ratio = WCAGContrast.ratio(composited, fill)

        #expect(ratio >= 7.0)
    }

    @Test("Increase Contrast : la cible passe a 7:1 et l'aplat sombre obtenu l'atteint reellement (blanc 95%)")
    func increasedContrastFillMeets7to1InDark() {
        let fill = SlateAccent.selectionFillDarkRGBIncreasedContrast
        let composited = WCAGContrast.compositeOverBackground(Self.white95, fill)
        let ratio = WCAGContrast.ratio(composited, fill)

        #expect(ratio >= 7.0)
    }

    @Test("Increase Contrast : l'aplat 7:1 est nettement plus sombre que l'aplat 4,5:1 (meme accent)")
    func increasedContrastFillIsSubstantiallyDarker() {
        // Le rapport de livraison documente ce point explicitement : ce n'est pas une
        // simple nuance, c'est un bleu visiblement different. Luminance relative plutot
        // qu'une composante isolee (`.red` vaut 0 pour ces accents).
        #expect(
            WCAGContrast.relativeLuminance(SlateAccent.selectionFillLightRGBIncreasedContrast)
                < WCAGContrast.relativeLuminance(SlateAccent.selectionFillLightRGB) * 0.8
        )
        #expect(
            WCAGContrast.relativeLuminance(SlateAccent.selectionFillDarkRGBIncreasedContrast)
                < WCAGContrast.relativeLuminance(SlateAccent.selectionFillDarkRGB) * 0.8
        )
    }

    @Test("Increase Contrast : text.secondary vaut bien 0,72 d'opacite dans les deux themes")
    func textSecondaryIncreasedContrastOpacity() {
        #expect(SlateTextOpacity.secondaryIncreasedContrast == 0.72)
        // Hors Increase Contrast, les valeurs de la phase 3 restent inchangees (0,50 / 0,55).
        #expect(SlateTextOpacity.secondaryLight == 0.50)
        #expect(SlateTextOpacity.secondaryDark == 0.55)
    }

    private func requireRGB(_ hex: String) throws -> SlateRGB {
        try #require(SlateRGB(hex: hex))
    }
}
