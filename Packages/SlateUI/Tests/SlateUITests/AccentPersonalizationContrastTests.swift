import Testing
@testable import SlateUI

/// Verifie les deux corrections de fond de la Phase 13 (accent personnalisable,
/// design/tokens.md §7) :
/// 1. `text.onAccent` est une FONCTION de l'accent (et du theme), pas une constante
///    blanche -- `SlateAccentColor.onAccentRGB(dark:)`.
/// 2. `text.link` est DERIVE de l'accent courant sur `bg.editor` -- `SlateAccentColor.
///    linkRGB(dark:)`.
///
/// Tous les cas testes ici passent par les fonctions PURES de `SlateAccentColor` (aucune
/// dependance a `ThemeManager.shared`) : verifier les 8 accents ne doit pas dependre de
/// l'ordre d'execution des tests ni muter un singleton partage.
@Suite("Accent personnalisable - text.onAccent par accent")
struct OnAccentPerAccentContrastTests {
    /// Compose `foreground` (peut etre translucide : noir 85%) sur l'aplat de `accent`
    /// avant de mesurer le ratio -- meme methode que `ContrastRatioTests` pour tout
    /// premier plan translucide (voir `WCAGContrast.compositeOverBackground`, "le piege
    /// corrige").
    private func composedRatio(_ foreground: SlateRGB, on background: SlateRGB) -> Double {
        WCAGContrast.ratio(WCAGContrast.compositeOverBackground(foreground, background), background)
    }

    /// NOTE DE LIVRAISON : `design/tokens.md` §7 avance des ratios precis (ex. rose
    /// 4,16:1, orange 7,05:1, vert 6,54:1...) que ce calcul WCAG 2.1 correct (compositant
    /// bien l'alpha du noir 85%) NE REPRODUIT PAS a l'identique -- ecarts de 0,1 a 1,3
    /// point selon l'accent, dans les deux sens (parfois au-dessus, parfois en dessous de
    /// la mesure du design). Ce n'est pas nouveau : `ContrastRatioTests` documentait deja
    /// une erreur de la spec E2 sur ce meme calcul (4,55 annonce vs 4,02 reel). Plutot que
    /// d'ajuster ce test pour retomber sur les chiffres du design, on verifie ici la
    /// REGLE (quelle couleur choisir, et qu'elle est effectivement la meilleure des deux
    /// options mesurees ICI) -- voir le rapport de livraison pour le detail chiffre
    /// accent par accent.
    @Test(
        "Le noir 85% choisi pour orange/jaune/vert est mesurablement meilleur que le blanc, en clair ET en sombre",
        arguments: [SlateAccentColor.orange, .yellow, .green]
    )
    func warmTintsBlackChoiceIsMeasurablyBetter(accent: SlateAccentColor) {
        let blackLight = composedRatio(SlateRGB(red: 0, green: 0, blue: 0, alpha: 0.85), on: accent.lightRGB)
        let whiteLight = composedRatio(.white, on: accent.lightRGB)
        let blackDark = composedRatio(SlateRGB(red: 0, green: 0, blue: 0, alpha: 0.85), on: accent.darkRGB)
        let whiteDark = composedRatio(.white, on: accent.darkRGB)

        #expect(accent.onAccentRGB(dark: false) != .white)
        #expect(accent.onAccentRGB(dark: true) != .white)
        #expect(blackLight > whiteLight)
        #expect(blackDark > whiteDark)
        #expect(blackLight >= 4.5)
        #expect(blackDark >= 4.5)
    }

    @Test("Le graphite choisit noir 85% en sombre, blanc en clair -- et chaque choix tient l'AA")
    func graphiteChoiceMeetsAAInBothThemes() {
        #expect(SlateAccentColor.graphite.onAccentRGB(dark: false) == .white)
        #expect(SlateAccentColor.graphite.onAccentRGB(dark: true) != .white)

        let graphite = SlateAccentColor.graphite
        let lightRatio = composedRatio(graphite.onAccentRGB(dark: false), on: graphite.lightRGB)
        let darkRatio = composedRatio(graphite.onAccentRGB(dark: true), on: graphite.darkRGB)
        // Le clair (blanc) reste l'"ecart assume" documente par le design (~3,0-3,3:1,
        // sous l'AA) ; le sombre (noir 85%), lui, doit tenir l'AA -- c'est precisement
        // la correction n01 pour cet accent.
        #expect(lightRatio < 4.5)
        #expect(darkRatio >= 4.5)
    }

    @Test("Le graphite est le seul accent ou le sombre est plus exigeant que le clair")
    func graphiteSwitchesToBlackOnlyInDark() {
        #expect(SlateAccentColor.graphite.onAccentRGB(dark: false) == .white)
        #expect(SlateAccentColor.graphite.onAccentRGB(dark: true) != .white)
    }

    @Test("Orange, jaune et vert utilisent du noir 85% dans les deux themes")
    func warmTintsAlwaysUseBlackText() {
        for accent: SlateAccentColor in [.orange, .yellow, .green] {
            #expect(accent.onAccentRGB(dark: false) != .white)
            #expect(accent.onAccentRGB(dark: true) != .white)
        }
    }

    @Test("Bleu, violet, rose et rouge restent en blanc dans les deux themes (ecart assume)")
    func coolTintsAlwaysUseWhiteText() {
        for accent: SlateAccentColor in [.blue, .purple, .pink, .red] {
            #expect(accent.onAccentRGB(dark: false) == .white)
            #expect(accent.onAccentRGB(dark: true) == .white)
        }
    }
}

/// "Augmenter le contraste" (design/tokens.md §7) : les quatre teintes qui restent sous
/// l'AA texte (3,0-4,2:1) avec du blanc sont assombries de 12% pour repasser au-dessus de
/// 4,5:1. Les quatre autres, deja au-dessus avec leur `onAccentRGB`, restent inchangees.
@Suite("Accent personnalisable - Augmenter le contraste")
struct IncreasedContrastAccentTests {
    @Test(
        "Les 4 teintes basses repassent au-dessus de l'AA sous Augmenter le contraste, en clair",
        arguments: [SlateAccentColor.blue, .purple, .pink, .red]
    )
    func lowContrastTintsReachAAInLight(accent: SlateAccentColor) {
        let baseRatio = WCAGContrast.ratio(.white, accent.fillRGB(dark: false, increasedContrast: false))
        let hcRatio = WCAGContrast.ratio(.white, accent.fillRGB(dark: false, increasedContrast: true))
        #expect(baseRatio < 4.5)
        #expect(hcRatio >= 4.5)
    }

    @Test(
        "Les 4 teintes basses repassent au-dessus de l'AA sous Augmenter le contraste, en sombre",
        arguments: [SlateAccentColor.blue, .purple, .pink, .red]
    )
    func lowContrastTintsReachAAInDark(accent: SlateAccentColor) {
        let hcRatio = WCAGContrast.ratio(.white, accent.fillRGB(dark: true, increasedContrast: true))
        #expect(hcRatio >= 4.5)
    }

    @Test(
        "Les 4 teintes deja hautes ne changent pas sous Augmenter le contraste",
        arguments: [SlateAccentColor.orange, .yellow, .green, .graphite]
    )
    func highContrastTintsAreUnchangedByIncreasedContrast(accent: SlateAccentColor) {
        #expect(accent.fillRGB(dark: false, increasedContrast: true) == accent.lightRGB)
        #expect(accent.fillRGB(dark: true, increasedContrast: true) == accent.darkRGB)
    }
}

/// `text.link` (design/tokens.md, "Couleur de texte derivee de l'accent") : chaque accent,
/// pose EN TEXTE sur `bg.editor`, doit tenir l'AA (4,5:1) -- notamment le vert, qui motive
/// toute la correction (accent brut #34C759 sur fond blanc = 2,0:1, tres sous l'AA).
@Suite("Accent personnalisable - text.link derive")
struct DerivedLinkContrastTests {
    private static let editorBackgroundLight = SlateRGB(hex: "#FFFFFF") ?? .white
    private static let editorBackgroundDark = SlateRGB(hex: "#1C1C1E") ?? .black

    @Test(
        "Le lien derive tient l'AA sur bg.editor clair, pour chacun des 8 accents",
        arguments: SlateAccentColor.allCases
    )
    func linkMeetsAAInLight(accent: SlateAccentColor) {
        let ratio = WCAGContrast.ratio(accent.linkRGB(dark: false), Self.editorBackgroundLight)
        #expect(ratio >= 4.5)
    }

    @Test(
        "Le lien derive tient l'AA sur bg.editor sombre, pour chacun des 8 accents",
        arguments: SlateAccentColor.allCases
    )
    func linkMeetsAAInDark(accent: SlateAccentColor) {
        let ratio = WCAGContrast.ratio(accent.linkRGB(dark: true), Self.editorBackgroundDark)
        #expect(ratio >= 4.5)
    }

    @Test("L'accent vert brut echoue largement l'AA sur bg.editor clair : c'est ce que corrige linkRGB")
    func rawGreenFailsAA() {
        let rawRatio = WCAGContrast.ratio(SlateAccentColor.green.lightRGB, Self.editorBackgroundLight)
        let derivedRatio = WCAGContrast.ratio(SlateAccentColor.green.linkRGB(dark: false), Self.editorBackgroundLight)
        #expect(rawRatio < 2.5)
        #expect(derivedRatio >= 4.5)
        #expect(derivedRatio > rawRatio)
    }

    /// NOTE DE LIVRAISON : contrairement a l'exemple illustratif de `design/tokens.md`
    /// ("bleu sombre #6CB6FF (6,04:1) au lieu de #0A84FF (3,56:1)"), l'accent bleu sombre
    /// BRUT tient DEJA l'AA sur `bg.editor` sombre dans ce calcul (~4,66:1) -- le 3,56:1
    /// cite par le design est le ratio de `text.onAccent` (blanc SUR l'aplat bleu), pas
    /// celui de l'accent POSE EN TEXTE sur `bg.editor` : deux mesures differentes, memes
    /// deux nombres qui se ressemblent. `linkRGB` retourne donc le bleu sombre INCHANGE
    /// (`WCAGContrast.lightening` n'agit que si necessaire) : c'est le comportement
    /// attendu de la regle ("eclaircir jusqu'a l'AA, pas au-dela"), pas un defaut.
    @Test("L'accent bleu sombre tient deja l'AA brut sur bg.editor sombre : linkRGB ne le modifie pas inutilement")
    func rawDarkBlueAlreadyMeetsAA() {
        let rawRatio = WCAGContrast.ratio(SlateAccentColor.blue.darkRGB, Self.editorBackgroundDark)
        let derivedRatio = WCAGContrast.ratio(SlateAccentColor.blue.linkRGB(dark: true), Self.editorBackgroundDark)
        #expect(rawRatio >= 4.5)
        #expect(derivedRatio >= 4.5)
    }
}

/// Integration : `SlateColor`/`SlateSemanticColors` lisent bien `ThemeManager.shared.
/// accent` (et pas seulement `SlateAccentColor` en isolation). `ThemeManager` etant un
/// singleton partage a l'echelle du processus de test, chaque test restaure l'accent par
/// defaut en sortie (`defer`) pour ne pas polluer les autres suites.
@Suite("Accent personnalisable - ThemeManager relie bien les tokens", .serialized)
@MainActor
struct ThemeManagerIntegrationTests {
    @Test("SlateAccent.defaultLightRGB/defaultDarkRGB suivent ThemeManager.shared.accent")
    func slateAccentFollowsThemeManager() {
        let original = ThemeManager.shared.accent
        defer { ThemeManager.shared.accent = original }

        ThemeManager.shared.accent = .green
        #expect(SlateAccent.defaultLightRGB == SlateAccentColor.green.lightRGB)
        #expect(SlateAccent.defaultDarkRGB == SlateAccentColor.green.darkRGB)
        #expect(slateCurrentAccent() == .green)

        ThemeManager.shared.accent = .blue
        #expect(SlateAccent.defaultLightRGB == SlateAccentColor.blue.lightRGB)
        #expect(slateCurrentAccent() == .blue)
    }

    @Test("selectionFillLightRGB se recalcule quand l'accent change")
    func selectionFillRecomputesOnAccentChange() {
        let original = ThemeManager.shared.accent
        defer { ThemeManager.shared.accent = original }

        ThemeManager.shared.accent = .blue
        let blueFill = SlateAccent.selectionFillLightRGB

        ThemeManager.shared.accent = .green
        let greenFill = SlateAccent.selectionFillLightRGB

        #expect(blueFill != greenFill)
    }
}
