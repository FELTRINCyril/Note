import SwiftUI

/// Valeurs RGB brutes de l'accent par defaut et de ses derives.
///
/// Expose separement de `SlateColor` (qui rend des `Color`) parce que les calculs de
/// contraste (tests, futur `AccentPicker` en Phase 13) ont besoin des composantes brutes,
/// pas d'un `Color` opaque. `defaultLightRGB` / `defaultDarkRGB` sont amenes a devenir
/// des parametres (accent choisi par l'utilisateur) plutot que des constantes : le calcul
/// `selectionFill*` doit rester une regle, pas une valeur figee, pour continuer a
/// garantir l'AA quel que soit l'accent (voir `ContrastRatio.swift`).
public enum SlateAccent {
    public static let defaultLightRGB = SlateRGB(hex: "#007AFF") ?? .black
    public static let defaultDarkRGB = SlateRGB(hex: "#0A84FF") ?? .black

    /// Premier plan SECONDAIRE pose sur l'aplat de selection (spec E3 : l'extrait de la
    /// cellule de note, "blanc 95%"). C'est ce premier plan -- pas le principal, opaque --
    /// qui doit contraindre l'assombrissement : il est strictement plus exigeant (voir
    /// `ContrastRatio.swift`, section "le piege corrige"). Cible aussi le calcul de
    /// `selectionFill*` ci-dessous, pour ne pas reproduire le defaut de phase 3 (regle
    /// calee sur le premier plan le plus facile, blanc opaque).
    public static let selectionForegroundSecondary = SlateRGB(red: 1, green: 1, blue: 1, alpha: 0.95)

    /// Accent clair assombri jusqu'a 4,5:1 pour le premier plan secondaire (blanc 95%).
    /// Ordre de grandeur attendu (voir `ContrastRatio.swift`) : proche de `#006DE3`
    /// (~4,58:1 pour le blanc 95%, ~4,91:1 pour le blanc opaque).
    public static let selectionFillLightRGB = WCAGContrast.darkening(
        defaultLightRGB,
        toReachContrast: 4.5,
        with: selectionForegroundSecondary
    )

    /// Accent sombre assombri jusqu'a 4,5:1 pour le premier plan secondaire. Ordre de
    /// grandeur attendu : proche de `#0870D9` (~4,53:1 pour le blanc 95%, ~4,84:1 pour le
    /// blanc opaque).
    public static let selectionFillDarkRGB = WCAGContrast.darkening(
        defaultDarkRGB,
        toReachContrast: 4.5,
        with: selectionForegroundSecondary
    )

    /// Variante "Increase Contrast" : cible 7:1 au lieu de 4,5:1 (spec E2/E3). Assombrit
    /// nettement plus (accent clair -> proche de `#0051A8`, ~34% plus sombre) : c'est un
    /// bleu visiblement different de l'accent par defaut, pas une simple nuance -- voir le
    /// rapport de livraison pour le jugement sur ce rendu.
    public static let selectionFillLightRGBIncreasedContrast = WCAGContrast.darkening(
        defaultLightRGB,
        toReachContrast: 7.0,
        with: selectionForegroundSecondary
    )

    /// Variante sombre "Increase Contrast", cible 7:1.
    public static let selectionFillDarkRGBIncreasedContrast = WCAGContrast.darkening(
        defaultDarkRGB,
        toReachContrast: 7.0,
        with: selectionForegroundSecondary
    )
}

/// Opacites de `text.secondary` (design/tokens.md §2), separees en constantes pures pour
/// rester testables sans dependre de `NSWorkspace` (voir `SlateAccessibility.swift`).
public enum SlateTextOpacity {
    /// `text.secondary` clair, hors Increase Contrast.
    public static let secondaryLight = 0.50
    /// `text.secondary` sombre, hors Increase Contrast.
    public static let secondaryDark = 0.55
    /// `text.secondary`, LES DEUX themes, quand Increase Contrast est actif (spec E2 :
    /// "les rangs secondaires passent de 0,50 a 0,72 en Increase Contrast").
    public static let secondaryIncreasedContrast = 0.72

    /// `text.placeholder` clair, hors Increase Contrast (Phase 5, E4).
    public static let placeholderLight = 0.25
    /// `text.placeholder` sombre, hors Increase Contrast (Phase 5, E4).
    public static let placeholderDark = 0.25
    /// `text.placeholder` clair sous Increase Contrast.
    ///
    /// ECART ASSUME PAR RAPPORT A LA LETTRE DE LA SPEC E4, valide par Cyril. La spec
    /// ecrit "0,52" mais annonce dans la meme phrase l'objectif "le placeholder passe
    /// alors AA (4,6:1)". Or 0,52 compose sur `bg.editor` clair ne donne que 4,27:1,
    /// donc rate l'AA et rate l'objectif annonce. 0,54 donne 4,59:1, soit exactement la
    /// valeur que la spec annonce : le designer a vraisemblablement calcule 0,54 et
    /// ecrit 0,52. On suit donc l'INTENTION mesuree plutot que le chiffre, comme pour
    /// l'aplat d'accent de la phase 3. Verifie par `EditorAccessibilityTests`.
    public static let placeholderLightIncreasedContrast = 0.54
    /// `text.placeholder` sombre sous Increase Contrast (spec E4). Mesure reelle
    /// ~6,48:1 sur `bg.editor` : celui-ci atteint bien l'AA (et presque l'AAA).
    public static let placeholderDarkIncreasedContrast = 0.58
}
