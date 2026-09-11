import SwiftUI

/// Valeurs RGB brutes de l'accent COURANT et de ses derives.
///
/// Expose separement de `SlateColor` (qui rend des `Color`) parce que les calculs de
/// contraste (tests, `AccentPicker` de la fenetre de reglages) ont besoin des composantes
/// brutes, pas d'un `Color` opaque.
///
/// `defaultLightRGB` / `defaultDarkRGB` sont des PROPRIETES CALCULEES (Phase 13, accent
/// personnalisable) : elles lisent `slateCurrentAccent()` -- donc `ThemeManager.shared.
/// accent` -- a chaque acces, comme `SlateColor.textSecondary` lit "Increase Contrast".
/// Idem pour `selectionFill*`, qui en decoulent : le calcul reste une REGLE reappliquee a
/// chaque accent choisi, jamais une valeur figee, pour continuer a garantir l'AA quel que
/// soit l'accent (voir `ContrastRatio.swift`). Pour la couleur de l'accent BLEU par
/// defaut specifiquement (independamment du choix utilisateur), voir `SlateAccentColor.
/// blue`.
public enum SlateAccent {
    public static var defaultLightRGB: SlateRGB { slateCurrentAccent().lightRGB }
    public static var defaultDarkRGB: SlateRGB { slateCurrentAccent().darkRGB }

    /// Premier plan SECONDAIRE pose sur l'aplat de selection (spec E3 : l'extrait de la
    /// cellule de note, "blanc 95%"). C'est ce premier plan -- pas le principal, opaque --
    /// qui doit contraindre l'assombrissement : il est strictement plus exigeant (voir
    /// `ContrastRatio.swift`, section "le piege corrige"). Cible aussi le calcul de
    /// `selectionFill*` ci-dessous, pour ne pas reproduire le defaut de phase 3 (regle
    /// calee sur le premier plan le plus facile, blanc opaque).
    public static let selectionForegroundSecondary = SlateRGB(red: 1, green: 1, blue: 1, alpha: 0.95)

    /// Accent clair courant assombri jusqu'a 4,5:1 pour le premier plan secondaire (blanc
    /// 95%). Pour l'accent bleu par defaut, ordre de grandeur attendu (voir
    /// `ContrastRatio.swift`) : proche de `#006DE3` (~4,58:1 pour le blanc 95%, ~4,91:1
    /// pour le blanc opaque).
    public static var selectionFillLightRGB: SlateRGB {
        WCAGContrast.darkening(defaultLightRGB, toReachContrast: 4.5, with: selectionForegroundSecondary)
    }

    /// Accent sombre courant assombri jusqu'a 4,5:1 pour le premier plan secondaire. Pour
    /// l'accent bleu par defaut, ordre de grandeur attendu : proche de `#0870D9`
    /// (~4,53:1 pour le blanc 95%, ~4,84:1 pour le blanc opaque).
    public static var selectionFillDarkRGB: SlateRGB {
        WCAGContrast.darkening(defaultDarkRGB, toReachContrast: 4.5, with: selectionForegroundSecondary)
    }

    /// Variante "Increase Contrast" : cible 7:1 au lieu de 4,5:1 (spec E2/E3). Assombrit
    /// nettement plus (accent bleu par defaut -> proche de `#0051A8`, ~34% plus sombre) :
    /// un bleu visiblement different de l'accent par defaut, pas une simple nuance -- voir
    /// le rapport de livraison de la phase 4 pour le jugement sur ce rendu.
    public static var selectionFillLightRGBIncreasedContrast: SlateRGB {
        WCAGContrast.darkening(defaultLightRGB, toReachContrast: 7.0, with: selectionForegroundSecondary)
    }

    /// Variante sombre "Increase Contrast", cible 7:1.
    public static var selectionFillDarkRGBIncreasedContrast: SlateRGB {
        WCAGContrast.darkening(defaultDarkRGB, toReachContrast: 7.0, with: selectionForegroundSecondary)
    }
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

    /// `text.placeholder` clair, hors Increase Contrast.
    ///
    /// CORRIGE en Phase 7 (design/tokens.md §2, "corrige") : 0,25 (valeur Phase 1-6)
    /// composait a seulement 1,83:1 sur `bg.editor` clair, tres sous l'AA -- un
    /// placeholder porte une consigne ("Tapez / pour les commandes"), contrairement a
    /// `text.disabled` (qui reste a 0,25, aucune obligation AA pour un controle
    /// desactive). 0,55 donne 4,76:1, verifie par `EditorAccessibilityTests`.
    public static let placeholderLight = 0.55
    /// `text.placeholder` sombre, hors Increase Contrast. Corrige en Phase 7, voir
    /// `placeholderLight`. 0,60 donne ~6,85:1 sur `bg.editor` sombre.
    public static let placeholderDark = 0.60
    /// `text.placeholder` clair sous Increase Contrast. Corrige en Phase 7 (le calcul de
    /// base atteignant deja l'AA, la variante HC vise desormais un renfort net au-dela,
    /// pas seulement le seuil AA) : 0,70 donne ~8,52:1. Verifie par `EditorAccessibilityTests`.
    public static let placeholderLightIncreasedContrast = 0.70
    /// `text.placeholder` sombre sous Increase Contrast. Corrige en Phase 7 : 0,78 donne
    /// ~10,71:1 sur `bg.editor` sombre.
    public static let placeholderDarkIncreasedContrast = 0.78
}
