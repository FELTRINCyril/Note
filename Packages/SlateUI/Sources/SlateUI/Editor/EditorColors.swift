import SwiftUI

/// Composantes RGB brutes de `block.selected.bg` (design/tokens.md §16), separees en
/// constantes pures pour rester testables sans risquer `MainActor.assumeIsolated`
/// (voir `SlateAccessibility.swift`) : Swift Testing ne garantit pas que chaque test
/// s'execute sur le thread principal, contrairement au rendu SwiftUI. Meme motif que
/// `SlateAccent.selectionFillLightRGB` / `SlateTextOpacity` (Phases 3-4) : le token
/// `Color` (`SlateColor.blockSelectedBackground`) n'est lu que depuis le rendu de vues
/// ou des previews ; les tests lisent ces `SlateRGB` bruts avec `WCAGContrast`.
public enum SlateBlockSelection {
    /// Aplat clair, hors Increase Contrast. Spec E4 : "12 % clair".
    public static let backgroundLightRGB = SlateRGB(red: 0, green: 122.0 / 255, blue: 255.0 / 255, alpha: 0.12)
    /// Aplat sombre, hors Increase Contrast. Spec E4 : "20 % sombre".
    public static let backgroundDarkRGB = SlateRGB(red: 10.0 / 255, green: 132.0 / 255, blue: 255.0 / 255, alpha: 0.20)
    /// Aplat clair sous Increase Contrast. Spec E4 : "montant a 22 %".
    public static let backgroundLightIncreasedContrastRGB = SlateRGB(
        red: 0, green: 122.0 / 255, blue: 255.0 / 255, alpha: 0.22
    )
    /// Aplat sombre sous Increase Contrast. Spec E4 : "montant a ... 32 %".
    public static let backgroundDarkIncreasedContrastRGB = SlateRGB(
        red: 10.0 / 255, green: 132.0 / 255, blue: 255.0 / 255, alpha: 0.32
    )
}

/// Tokens de couleur de l'editeur de blocs (design/tokens.md §16, spec E4). Etend
/// `SlateColor` plutot que d'introduire un second namespace de couleurs concurrent :
/// c'est la meme convention que `SlateFolderColor` (extension separee, meme enum
/// consommateur).
public extension SlateColor {
    /// `block.selected.bg`. Aplat d'un bloc (ou d'une plage de blocs) selectionne dans
    /// l'editeur.
    ///
    /// Propriete CALCULEE (pas `let`), comme `textSecondary`/`accentSelectionFill` :
    /// passe de 12 %/20 % a 22 %/32 % sous "Increase Contrast" (spec E4, "Mesure de
    /// contraste"), donc doit se relire a chaque acces plutot qu'etre figee au premier
    /// rendu. VERIFIE par calcul (`EditorAccessibilityTests`) : le texte pose dessus
    /// (`text.primary`, 0,85 d'opacite) mesure en realite ~13,4:1 (clair) / ~10,0:1
    /// (sombre) hors Increase Contrast -- la spec annonce 12,4:1 / 9,6:1, un ecart de
    /// mesure (les DEUX depassent tres largement l'AAA, 7:1, donc aucun probleme
    /// d'accessibilite reel derriere cet ecart, contrairement au cas du contour de
    /// focus ci-dessous).
    static var blockSelectedBackground: Color {
        slateAdaptiveColor(
            light: SlateBlockSelection.backgroundLightRGB,
            dark: SlateBlockSelection.backgroundDarkRGB,
            lightHC: SlateBlockSelection.backgroundLightIncreasedContrastRGB,
            darkHC: SlateBlockSelection.backgroundDarkIncreasedContrastRGB
        )
    }

    /// `code.block.bg`. Fond d'un bloc de code. Reserve a la Phase 8 (bloc de code)
    /// mais expose ici : c'est un token §16 du design system, pas un composant.
    static let codeBlockBackground = slateAdaptiveColor(
        light: SlateRGB(hex: "#F5F5F7") ?? .white,
        dark: SlateRGB(hex: "#2A2A2C") ?? .black
    )

    /// `quote.barColor`. Barre laterale d'un bloc de citation. Reserve aux Phases 6/7
    /// (blocs riches) mais expose ici pour la meme raison que `codeBlockBackground`.
    static let quoteBarColor = slateAdaptiveColor(
        light: SlateRGB(hex: "#D1D1D6") ?? .white,
        dark: SlateRGB(hex: "#48484A") ?? .black
    )

    /// `divider.color` = `separator`. Alias nomme pour la tracabilite avec le bloc
    /// "separateur" de l'editeur (Phase 6/7) : le token §16 pointe explicitement vers
    /// `separator`, ce n'est pas une nouvelle teinte.
    static let dividerColor = separator

    /// `block.dropIndicator` = `accent.default`. Ligne d'insertion affichee pendant un
    /// glisser-depose de bloc.
    static let blockDropIndicator = accentDefault

    /// Curseur de saisie (`insertionPoint` macOS = couleur d'accent). Spec E4 : "Caret.
    /// 2 pt, accent.default".
    static let caretColor = accentDefault

    // MARK: - Chrome de bloc (poignee et bouton d'insertion)
    // Pas de token dedie dans §16 : derive de §2 (texte) et §3 (etats), comme le reste
    // du chrome d'UI transverse (cf. `sidebarChevron = textTertiary`).

    /// Teinte du glyphe de chrome de bloc au repos (spec E4, galerie d'etats : "glyphes
    /// text.tertiary").
    static let blockHandleIdle = textTertiary

    /// Teinte du glyphe de chrome de bloc au survol du BOUTON (spec E4 : "glyphe
    /// text.secondary"). Propriete CALCULEE : `textSecondary` l'est deja (Increase
    /// Contrast), la reactivite doit se propager.
    static var blockHandleHover: Color { textSecondary }

    /// Fond du bouton de chrome de bloc au survol (spec E4 : "fond state.hover").
    static let blockHandleHoverBackground = stateHover

    /// Fond du bouton de chrome de bloc presse.
    static let blockHandlePressedBackground = statePressed

    // MARK: - Elevation (design/tokens.md §13)

    /// Ombre portee `elevation.medium`, consommee par la barre de formatage flottante
    /// (artboard P1 A, Phase 7). Voir `SlateGeometry.formatBarShadowRadius`/`formatBarShadowY`
    /// pour le rayon et le decalage associes.
    static let elevationMediumShadow = slateAdaptiveColor(
        light: SlateRGB(red: 0, green: 0, blue: 0, alpha: 0.12),
        dark: SlateRGB(red: 0, green: 0, blue: 0, alpha: 0.40)
    )

    /// Ombre portee `elevation.high` (design/tokens.md §13 : "y:10 blur:30",
    /// "Modales, drag"), consommee par le fantome de bloc en cours de glissement
    /// (`BlockDragGhostView`, Phase 10). Voir `SlateGeometry.dragGhostShadowRadius`/
    /// `dragGhostShadowY` pour le rayon et le decalage associes.
    static let elevationHighShadow = slateAdaptiveColor(
        light: SlateRGB(red: 0, green: 0, blue: 0, alpha: 0.20),
        dark: SlateRGB(red: 0, green: 0, blue: 0, alpha: 0.55)
    )
}
