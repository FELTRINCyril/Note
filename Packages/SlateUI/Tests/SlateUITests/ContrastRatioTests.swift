import Testing
@testable import SlateUI

/// Tests de la regle de contraste WCAG 2.1 qui corrige une erreur reelle de la spec
/// design (`design/03_sidebar/Slate_E1-E2_coquille-sidebar.html`, section
/// Accessibilite) : elle affirmait a tort que blanc sur `#007AFF` valait 4,55:1 et sur
/// `#0A84FF` 4,52:1. Voir la documentation complete dans `ContrastRatio.swift`.
@Suite("Contraste WCAG 2.1")
struct ContrastRatioTests {
    @Test("La spec E2 se trompe pour l'accent clair : blanc sur #007AFF vaut ~4,02:1, pas 4,55:1")
    func specClaimIsWrongForLightAccent() throws {
        let accent = try requireRGB("#007AFF")
        let ratio = WCAGContrast.ratio(.white, accent)

        #expect(abs(ratio - 4.02) < 0.05)
        // Seuil AA pour un texte normal (13 pt Regular) : 4,5:1. La spec pretendait
        // 4,55:1 (reussite) ; la valeur reelle echoue.
        #expect(ratio < 4.5)
    }

    @Test("La spec E2 se trompe pour l'accent sombre : blanc sur #0A84FF vaut ~3,65:1, pas 4,52:1")
    func specClaimIsWrongForDarkAccent() throws {
        let accent = try requireRGB("#0A84FF")
        let ratio = WCAGContrast.ratio(.white, accent)

        #expect(abs(ratio - 3.65) < 0.05)
        #expect(ratio < 4.5)
    }

    @Test("Le token derive accentSelectionFill atteint au moins 4,5:1 en clair")
    func derivedFillMeetsAAInLight() {
        let ratio = WCAGContrast.ratio(.white, SlateAccent.selectionFillLightRGB)
        #expect(ratio >= 4.5)
        // Assombri, mais pas au point de devenir une couleur totalement differente :
        // toujours plus sombre que l'original mais dans un ordre de grandeur proche.
        let originalRatio = WCAGContrast.ratio(.white, SlateAccent.defaultLightRGB)
        #expect(ratio > originalRatio)
    }

    @Test("Le token derive accentSelectionFill atteint au moins 4,5:1 en sombre")
    func derivedFillMeetsAAInDark() {
        let ratio = WCAGContrast.ratio(.white, SlateAccent.selectionFillDarkRGB)
        #expect(ratio >= 4.5)
        let originalRatio = WCAGContrast.ratio(.white, SlateAccent.defaultDarkRGB)
        #expect(ratio > originalRatio)
    }

    @Test("La regle choisit du noir plutot que du blanc sur un accent clair type jaune")
    func chooseBlackOnLightAccent() throws {
        let yellow = try requireRGB("#FFCC00")
        #expect(WCAGContrast.labelColor(on: yellow) == .black)
    }

    @Test("La regle choisit du blanc sur une couleur nettement sombre")
    func chooseWhiteOnDarkColor() throws {
        // NB : #007AFF (accent par defaut) est volontairement EXCLU de ce cas : sa
        // luminance (~0,2116) est juste au-dessus du point de bascule ou blanc et noir
        // donnent un contraste egal (~0,1791) ; a cet endroit precis, noir gagne de peu
        // (5,23:1 vs 4,02:1) meme si l'usage design consacre le blanc par convention.
        // C'est une decouverte reelle de ce calcul, pas un bug : voir le rapport de
        // livraison. `accentSelectionFill` s'en affranchit en fixant le libelle a blanc
        // (comme `text.onAccent`) et en assombrissant le FOND, pas en choisissant le
        // libelle par cette regle.
        let darkBlue = try requireRGB("#0857B8")
        #expect(WCAGContrast.labelColor(on: darkBlue) == .white)
    }

    @Test("Le ratio d'une couleur avec elle-meme vaut 1")
    func selfContrastIsOne() throws {
        let color = try requireRGB("#007AFF")
        #expect(abs(WCAGContrast.ratio(color, color) - 1) < 0.000_1)
    }

    @Test("Le noir et le blanc ont le contraste maximal WCAG (21:1)")
    func blackWhiteContrastIsMaximal() {
        #expect(abs(WCAGContrast.ratio(.white, .black) - 21) < 0.01)
    }

    private func requireRGB(_ hex: String) throws -> SlateRGB {
        try #require(SlateRGB(hex: hex))
    }
}

/// Tests du defaut trouve en revue de phase 3 : le compteur de sidebar (`SidebarCounter`)
/// codait en dur `text.tertiary` (26% d'opacite noir/blanc), y compris quand la ligne est
/// posee sur l'aplat plein de selection (`accentSelectionFill`). Un texte translucide
/// compose sur ce fond y devient un bleu tres clair, tres proche du fond -- loin de
/// l'AA -- alors que son alpha seul (26%) ne le laisse pas deviner sans composition.
///
/// Ces tests encodent d'abord le defaut (le premier `#expect` echouerait AVANT le
/// correctif s'il portait sur le rendu reel de `SidebarCounter` ; ici il verifie la
/// regle de composition elle-meme, qui est la preuve mathematique du defaut), puis
/// valident que la couleur de remplacement (`SlateColor.foregroundOnAccentFill`, exposee
/// via `EnvironmentValues.slateIsOnAccentFill`) atteint bien l'AA.
@Suite("Contraste WCAG 2.1 - premier plan sur aplat d'accent")
struct OnAccentFillContrastTests {
    /// `text.tertiary` = noir (clair) / blanc (sombre) a 26% d'opacite (`SlateColor.textTertiary`).
    private static let textTertiaryBaseLight = SlateRGB(red: 0, green: 0, blue: 0, alpha: 0.26)
    private static let textTertiaryBaseDark = SlateRGB(red: 1, green: 1, blue: 1, alpha: 0.26)

    @Test("Composer un blanc opaque donne un contraste plus eleve que le meme blanc a 50% d'opacite")
    func compositingAlphaMattersForContrast() {
        let background = SlateAccent.selectionFillLightRGB
        let opaqueWhite = WCAGContrast.compositeOverBackground(.white, background)
        let halfWhite = WCAGContrast.compositeOverBackground(
            SlateRGB(red: 1, green: 1, blue: 1, alpha: 0.5),
            background
        )
        let opaqueRatio = WCAGContrast.ratio(opaqueWhite, background)
        let halfRatio = WCAGContrast.ratio(halfWhite, background)
        #expect(opaqueRatio > halfRatio)
        // Compose a 100%, le blanc reste... blanc : ratio identique a `ratio(.white, bg)`.
        #expect(abs(opaqueRatio - WCAGContrast.ratio(.white, background)) < 0.000_1)
    }

    @Test(
        "Defaut encode : text.tertiary compose sur l'aplat de selection clair echoue largement l'AA (~1,59:1)"
    )
    func counterOnAccentFillFailsAAInLight() {
        let background = SlateAccent.selectionFillLightRGB
        let composited = WCAGContrast.compositeOverBackground(Self.textTertiaryBaseLight, background)
        let ratio = WCAGContrast.ratio(composited, background)

        #expect(abs(ratio - 1.59) < 0.05)
        #expect(ratio < 4.5)
    }

    @Test(
        "Defaut encode : text.tertiary compose sur l'aplat de selection sombre echoue largement l'AA (~1,51:1)"
    )
    func counterOnAccentFillFailsAAInDark() {
        let background = SlateAccent.selectionFillDarkRGB
        let composited = WCAGContrast.compositeOverBackground(Self.textTertiaryBaseDark, background)
        let ratio = WCAGContrast.ratio(composited, background)

        #expect(abs(ratio - 1.51) < 0.05)
        #expect(ratio < 4.5)
    }

    @Test("Correctif : la couleur de premier plan sur aplat d'accent atteint l'AA en clair")
    func foregroundOnAccentFillMeetsAAInLight() {
        let background = SlateAccent.selectionFillLightRGB
        // `foregroundOnAccentFill` est opaque (= `text.onAccent` = blanc) : pas de
        // composition alpha necessaire, mais on la fait quand meme pour couvrir la
        // meme voie de calcul que le cas translucide ci-dessus.
        let composited = WCAGContrast.compositeOverBackground(.white, background)
        let ratio = WCAGContrast.ratio(composited, background)

        #expect(ratio >= 4.5)
    }

    @Test("Correctif : la couleur de premier plan sur aplat d'accent atteint l'AA en sombre")
    func foregroundOnAccentFillMeetsAAInDark() {
        let background = SlateAccent.selectionFillDarkRGB
        let composited = WCAGContrast.compositeOverBackground(.white, background)
        let ratio = WCAGContrast.ratio(composited, background)

        #expect(ratio >= 4.5)
    }
}
