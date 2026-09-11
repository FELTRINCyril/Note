import SwiftUI

// Couleurs semantiques (design/tokens.md §4) et couleur de lien (§2).
//
// Extraites de `SlateColor.swift` pour tenir la limite `file_length` de SwiftLint.
// Meme regle que le fichier principal : aucune couleur litterale dans une vue, tout
// passe par un token nomme portant sa reference `design/tokens.md §N`.

extension SlateColor {
    /// Erreur / suppression. Equivalent `semantic.error`.
    ///
    /// ATTENTION (design P3, artboard C et B) : cette couleur ne porte JAMAIS un libelle
    /// de texte. Sur `surface.primary` en sombre elle tombe a 3,9:1, insuffisant pour du
    /// texte. Une action destructive met donc `semanticError` sur le seul GLYPHE et garde
    /// `textPrimary` pour le libelle. Pour un bouton destructif plein, voir la variante
    /// `semanticErrorFill` ci-dessous.
    public static let semanticError = slateAdaptiveColor(
        light: SlateRGB(hex: "#FF3B30") ?? .black,
        dark: SlateRGB(hex: "#FF453A") ?? .black
    )

    /// Aplat de bouton destructif. Equivalent de la variante stricte de `semantic.error`
    /// retenue par le design P3 : #C4271E donne 4,52:1 avec du blanc, la ou #FF3B30 ne
    /// donne que 3,94:1. Reserve au seul bouton de suppression definitive.
    public static let semanticErrorFill = slateAdaptiveColor(
        light: SlateRGB(hex: "#C4271E") ?? .black,
        dark: SlateRGB(hex: "#C4271E") ?? .black
    )

    /// Fond de bandeau d'avertissement doux (design P3, artboard B : bandeau "Les notes
    /// sont supprimees definitivement au bout de 30 jours."). Distinct de
    /// `semanticWarning` (reserve aux glyphes non textuels, 3:1 seulement) : cette
    /// paire fond/texte doit tenir l'AA TEXTE (voir `semanticWarningText`).
    public static let semanticWarningSubtle = slateAdaptiveColor(
        light: SlateRGB(hex: "#FFF4E5") ?? .black,
        dark: SlateRGB(hex: "#3A2E12") ?? .black
    )

    /// Texte/glyphe pose sur `semanticWarningSubtle` (design P3 : `#9A5700` en clair).
    public static let semanticWarningText = slateAdaptiveColor(
        light: SlateRGB(hex: "#9A5700") ?? .black,
        dark: SlateRGB(hex: "#FFD08A") ?? .black
    )

    /// Succes / tache cochee. Equivalent `semantic.success`.
    public static let semanticSuccess = slateAdaptiveColor(
        light: SlateRGB(hex: "#34C759") ?? .black,
        dark: SlateRGB(hex: "#30D158") ?? .black
    )

    /// Information. Equivalent `semantic.info`.
    public static let semanticInfo = slateAdaptiveColor(
        light: SlateRGB(hex: "#007AFF") ?? .black,
        dark: SlateRGB(hex: "#0A84FF") ?? .black
    )

    // MARK: - Lien hypertexte (design/tokens.md §2)

    /// Couleur d'un lien hypertexte. Equivalent `text.link`.
    ///
    /// `tokens.md` §2 le donne egal a `accent.default`, mais la note de §7 impose une
    /// variante assombrie (clair) / eclaircie (sombre) des que l'accent est pose EN TEXTE
    /// sur `bg.editor` : l'accent brut peut tomber tres bas (vert #34C759 = 2,0:1).
    ///
    /// CORRIGE en Phase 13 (l'accent est desormais personnalisable, design/tokens.md §7,
    /// "Couleur de texte derivee de l'accent") : propriete CALCULEE, DERIVEE de l'accent
    /// COURANT (`ThemeManager.shared.accent`) via `SlateAccentColor.linkRGB(dark:)`, et non
    /// plus une constante bleue -- sans quoi un accent vert donnerait un lien a 2,0:1 sur
    /// `bg.editor`. Voir `SlateAccentColor.linkRGB(dark:)` pour le calcul (assombrissement
    /// en clair via `WCAGContrast.darkening`, eclaircissement en sombre via
    /// `WCAGContrast.lightening`).
    ///
    /// Un lien n'est jamais signale par la seule couleur : il reste souligne (design P1 D).
    public static var textLink: Color {
        let accent = slateCurrentAccent()
        return slateAdaptiveColor(light: accent.linkRGB(dark: false), dark: accent.linkRGB(dark: true))
    }
}
