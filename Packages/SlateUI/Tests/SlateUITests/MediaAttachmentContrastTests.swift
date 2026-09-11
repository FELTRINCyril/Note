import Testing
@testable import SlateUI

/// Verifie par calcul les contrastes WCAG 2.1 des blocs media/pieces jointes ajoutes en
/// Phase 9 (design/tokens.md §16 quater, artboards A/B/D de
/// `Slate P2 - Medias & pieces jointes.dc.html`). Meme motif que
/// `BlockDecorationContrastTests` : on ne suppose jamais qu'un aplat pastel ou une teinte
/// translucide reste lisible, on la mesure.
@Suite("Contraste WCAG 2.1 - zone de depot (design/tokens.md §16 quater)")
struct MediaDropzoneContrastTests {
    private static let surfaceSecondaryLightRGB = SlateRGB(hex: "#F2F2F5") ?? .white
    private static let surfaceSecondaryDarkRGB = SlateRGB(hex: "#2C2C2E") ?? .black
    private static let accentSubtleLightRGB = SlateRGB(
        red: 0, green: 122.0 / 255, blue: 255.0 / 255, alpha: 0.12
    )
    private static let accentSubtleDarkRGB = SlateRGB(
        red: 10.0 / 255, green: 132.0 / 255, blue: 255.0 / 255, alpha: 0.22
    )

    /// "Ajouter une image" (`text.primary`) sur `media.dropzone.bg` (= `surface.secondary`),
    /// en clair comme en sombre.
    @Test("Le libelle de la zone de depot au repos tient l'AA")
    func idleLabelMeetsAA() {
        let textPrimaryLight = SlateRGB(red: 0, green: 0, blue: 0, alpha: 0.85)
        let textPrimaryDark = SlateRGB(red: 1, green: 1, blue: 1, alpha: 0.85)

        let lightComposited = WCAGContrast.compositeOverBackground(textPrimaryLight, Self.surfaceSecondaryLightRGB)
        let darkComposited = WCAGContrast.compositeOverBackground(textPrimaryDark, Self.surfaceSecondaryDarkRGB)

        #expect(WCAGContrast.ratio(lightComposited, Self.surfaceSecondaryLightRGB) >= 4.5)
        #expect(WCAGContrast.ratio(darkComposited, Self.surfaceSecondaryDarkRGB) >= 4.5)
    }

    /// "Deposer <fichier>" (`mediaDropzoneActiveLabel`, = libelle `info` des callouts) sur
    /// `media.dropzone.active.bg` (= `accent.subtle`), en clair comme en sombre. Reprend
    /// les valeurs deja mesurees par l'artboard D (6,93:1 clair, 6,04:1 sombre).
    @Test("Le libelle de survol de depot tient l'AA")
    func activeLabelMeetsAA() {
        let labelLight = SlateCalloutVariant.info.labelLightRGB
        let labelDark = SlateCalloutVariant.info.labelDarkRGB

        let bgEditorDarkRGB = SlateRGB(hex: "#1C1C1E") ?? .black
        let lightBackground = WCAGContrast.compositeOverBackground(Self.accentSubtleLightRGB, .white)
        let darkBackground = WCAGContrast.compositeOverBackground(Self.accentSubtleDarkRGB, bgEditorDarkRGB)

        #expect(WCAGContrast.ratio(labelLight, lightBackground) >= 4.5)
        #expect(WCAGContrast.ratio(labelDark, darkBackground) >= 4.5)
    }
}

@Suite("Contraste WCAG 2.1 - pastilles de type de fichier (design/tokens.md §16 quater)")
struct AttachmentIconContrastTests {
    private static let bgEditorLightRGB = SlateRGB(hex: "#FFFFFF") ?? .white
    private static let bgEditorDarkRGB = SlateRGB(hex: "#1C1C1E") ?? .black

    /// Chaque pastille teintee (PDF, tableur) tient l'AA avec son propre monogramme,
    /// une fois composee sur `bg.editor` (fond de la ligne de piece jointe). Artboard D :
    /// "Pastille PDF #B3261E ... 6,01:1. Pastille XLS #1E7A34 ... 4,96:1."
    @Test(
        "Le monogramme de chaque pastille teintee tient l'AA, en clair",
        arguments: [SlateAttachmentFileType.pdf, .spreadsheet]
    )
    func tintedLabelMeetsAAInLight(fileType: SlateAttachmentFileType) {
        guard let backgroundLightRGB = fileType.backgroundLightRGB else {
            Issue.record("Type de fichier sans fond translucide dedie : \(fileType)")
            return
        }
        let compositedBackground = WCAGContrast.compositeOverBackground(backgroundLightRGB, Self.bgEditorLightRGB)
        let ratio = WCAGContrast.ratio(fileType.labelLightRGB, compositedBackground)

        #expect(ratio >= 4.5)
    }

    @Test(
        "Le monogramme de chaque pastille teintee tient l'AA, en sombre",
        arguments: [SlateAttachmentFileType.pdf, .spreadsheet]
    )
    func tintedLabelMeetsAAInDark(fileType: SlateAttachmentFileType) {
        guard let backgroundDarkRGB = fileType.backgroundDarkRGB else {
            Issue.record("Type de fichier sans fond translucide dedie : \(fileType)")
            return
        }
        let compositedBackground = WCAGContrast.compositeOverBackground(backgroundDarkRGB, Self.bgEditorDarkRGB)
        let ratio = WCAGContrast.ratio(fileType.labelDarkRGB, compositedBackground)

        #expect(ratio >= 4.5)
    }

    /// La pastille de repli (`.generic`, `state.hover`) porte un GLYPHE (icone SF Symbol),
    /// pas du texte : le seuil WCAG applicable est celui des objets graphiques non
    /// textuels, 3:1 (comme `accentDefault`/`focusRing`, deja documentes sur ce seuil dans
    /// `SlateColor.swift`), pas 4,5:1. L'artboard B dessine d'ailleurs ce glyphe en
    /// `rgba(0,0,0,0.50)`, la meme opacite que `text.secondary` -- une opacite de TEXTE
    /// choisie ici pour un glyphe, cf. seuil retenu.
    @Test("Le glyphe de la pastille generique tient le seuil non textuel (3:1), en clair comme en sombre")
    func genericGlyphMeetsNonTextThreshold() {
        let hoverLightRGB = SlateRGB(red: 0, green: 0, blue: 0, alpha: 0.05)
        let hoverDarkRGB = SlateRGB(red: 1, green: 1, blue: 1, alpha: 0.07)
        let glyphLightRGB = SlateAttachmentFileType.generic.labelLightRGB
        let glyphDarkRGB = SlateAttachmentFileType.generic.labelDarkRGB

        let compositedHoverLight = WCAGContrast.compositeOverBackground(hoverLightRGB, Self.bgEditorLightRGB)
        let compositedHoverDark = WCAGContrast.compositeOverBackground(hoverDarkRGB, Self.bgEditorDarkRGB)

        let lightGlyph = WCAGContrast.compositeOverBackground(glyphLightRGB, compositedHoverLight)
        let darkGlyph = WCAGContrast.compositeOverBackground(glyphDarkRGB, compositedHoverDark)

        #expect(WCAGContrast.ratio(lightGlyph, compositedHoverLight) >= 3.0)
        #expect(WCAGContrast.ratio(darkGlyph, compositedHoverDark) >= 3.0)
    }
}

@Suite("Contraste WCAG 2.1 - ligne de cause d'erreur (design/tokens.md §16 quater)")
struct AttachmentErrorCauseContrastTests {
    /// "Ligne d'erreur `#FF8A82` sur `bg.editor` sombre : 6,42:1" (artboard D), plus son
    /// pendant clair (`#B3261E`, la teinte de la pastille PDF -- voir `MediaColors.swift`).
    @Test("La ligne de cause d'un echec d'import tient l'AA sur bg.editor, clair et sombre")
    func errorCauseMeetsAAOnEditorBackground() {
        let bgEditorLight = SlateRGB(hex: "#FFFFFF") ?? .white
        let bgEditorDark = SlateRGB(hex: "#1C1C1E") ?? .black
        let causeLight = SlateRGB(hex: "#B3261E") ?? .black
        let causeDark = SlateRGB(hex: "#FF8A82") ?? .white

        #expect(WCAGContrast.ratio(causeLight, bgEditorLight) >= 4.5)
        #expect(WCAGContrast.ratio(causeDark, bgEditorDark) >= 4.5)
    }
}
