import AppKit
import SwiftUI

/// Cree une couleur adaptative clair/sombre a partir de deux `SlateRGB`, via
/// `NSColor(name:dynamicProvider:)`. Suit automatiquement l'apparence de la fenetre
/// (donc aussi "Increase Contrast" si `NSAppearance` bascule sur un des deux cas de
/// base geres ici -- clair/sombre uniquement, cf. limite documentee sur `SlateColor`).
/// Lit `SlateAccessibility.shared.isIncreaseContrastEnabled` depuis un contexte non
/// isole. `SlateAccessibility` est `@MainActor` (elle observe une notification AppKit,
/// voir `SlateAccessibility.swift`) ; `SlateColor` reste un simple `enum` de constantes
/// et proprietes calculees, nonisole, car il est lu depuis des contextes tres varies
/// (corps de vue, previews, tests). `MainActor.assumeIsolated` est sur : ces proprietes
/// ne sont accedees que pendant le rendu SwiftUI (main thread) ou dans les tests
/// (main thread egalement, `SlateAccessibility` n'est jamais touchee depuis une tache
/// en arriere-plan).
/// Lit `SlateAccessibility.shared.isIncreaseContrastEnabled` depuis un contexte non
/// isole. `SlateAccessibility` est `@MainActor` (elle observe une notification AppKit,
/// voir `SlateAccessibility.swift`) ; `SlateColor` reste un simple `enum` de constantes
/// et proprietes calculees, nonisole, car il est lu depuis des contextes tres varies
/// (corps de vue, previews, tests). `MainActor.assumeIsolated` est sur : ces proprietes
/// ne sont accedees que pendant le rendu SwiftUI (main thread) ou dans les tests
/// (main thread egalement, `SlateAccessibility` n'est jamais touchee depuis une tache
/// en arriere-plan). Pas `private` : reutilise par `SlateAccent.swift`.
func slateCurrentlyIncreasesContrast() -> Bool {
    MainActor.assumeIsolated { SlateAccessibility.shared.isIncreaseContrastEnabled }
}

/// Pas `private` : reutilise par `SlateAccent.swift`, `SlateFolderColor.swift` et
/// `Editor/EditorColors.swift`.
///
/// `lightHC`/`darkHC` (Phase 5, E4) portent les variantes "Augmenter le contraste" DANS
/// le constructeur de couleur, plutot que de dupliquer un `if slateCurrentlyIncreasesContrast()`
/// dans chaque token qui en a besoin (idee reprise du helper `Color.slate(light:dark:
/// lightHC:darkHC:)` propose par Claude Design en Phase 5). Uniquement optionnelles :
/// un appel qui ne les fournit pas (tous les tokens des phases 1 a 4) reste identique
/// bit a bit a l'ancien comportement -- y compris l'absence d'appel a
/// `slateCurrentlyIncreasesContrast()`, pour ne pas imposer de nouvelle exigence
/// "premier acces sur le thread principal" a des tokens qui n'en avaient pas besoin
/// (voir la mise en garde de `SlateAccessibility.swift` : cette lecture doit rester
/// cantonnee au rendu SwiftUI/tests sur le thread principal). Les tokens qui ONT
/// besoin d'une variante HC (ex: `SlateColor.textPlaceholder`,
/// `SlateColor.blockSelectedBackground`) restent des proprietes CALCULEES (pas `let`),
/// pour la meme raison que `textSecondary`/`accentSelectionFill` : re-invoquer cette
/// fonction a chaque acces est ce qui les rend reactives au changement de preference
/// (voir la limite de `NSColor(name:dynamicProvider:)` documentee dans
/// `SlateAccessibility.swift`).
func slateAdaptiveColor(
    light: SlateRGB,
    dark: SlateRGB,
    lightHC: SlateRGB? = nil,
    darkHC: SlateRGB? = nil
) -> Color {
    // Ne lit "Increase Contrast" que si une variante HC est reellement fournie : les
    // appels existants (sans HC) ne changent pas de comportement.
    let increasesContrast = (lightHC != nil || darkHC != nil) && slateCurrentlyIncreasesContrast()
    let resolvedLight = increasesContrast ? (lightHC ?? light) : light
    let resolvedDark = increasesContrast ? (darkHC ?? dark) : dark
    return Color(nsColor: NSColor(name: nil) { appearance in
        let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let rgb = isDark ? resolvedDark : resolvedLight
        return NSColor(red: rgb.red, green: rgb.green, blue: rgb.blue, alpha: rgb.alpha)
    })
}

/// Tokens de couleur semantiques de Slate, alignes sur `design/tokens.md` (§1 a §8) et
/// sur `design/03_sidebar/Slate_E1-E2_coquille-sidebar.html` (Specifications E1/E2).
///
/// Toutes les couleurs sont adaptatives clair/sombre (`NSColor(name:dynamicProvider:)`) :
/// aucune vue ne doit tester `colorScheme` elle-meme pour choisir une teinte.
///
/// "Increase Contrast" (spec E2/E3 : aplat de selection recalcule pour 7:1, `text.
/// secondary` renforce a 0,72) EST implemente, mais pas via `NSColor(name:
/// dynamicProvider:)` -- cette API ne se re-declenche pas quand seule cette preference
/// change (voir la limite documentee dans `SlateAccessibility.swift`). `textSecondary`
/// et `accentSelectionFill` sont des proprietes CALCULEES qui lisent
/// `SlateAccessibility.shared` a chaque acces plutot que des `let` figes au premier
/// rendu.
public enum SlateColor {
    // MARK: - Fonds & surfaces (design/tokens.md §1)

    /// Fond de fenetre. Equivalent `bg.window`.
    public static let bgWindow = slateAdaptiveColor(
        light: SlateRGB(hex: "#ECECEC") ?? .white,
        dark: SlateRGB(hex: "#1E1E1E") ?? .black
    )

    /// Aplat de repli de la barre laterale quand "Reduce Transparency" est actif, ou base
    /// de teinte du materiau `.sidebar` sinon. Equivalent `bg.sidebar` (base).
    public static let bgSidebarOpaque = slateAdaptiveColor(
        light: SlateRGB(hex: "#F2F2F5") ?? .white,
        dark: SlateRGB(hex: "#232326") ?? .black
    )

    /// Fond de colonne liste. Equivalent `bg.list`.
    public static let bgList = slateAdaptiveColor(
        light: SlateRGB(hex: "#FFFFFF") ?? .white,
        dark: SlateRGB(hex: "#1E1E1E") ?? .black
    )

    /// Fond de zone d'edition. Equivalent `bg.editor`.
    public static let bgEditor = slateAdaptiveColor(
        light: SlateRGB(hex: "#FFFFFF") ?? .white,
        dark: SlateRGB(hex: "#1C1C1E") ?? .black
    )

    /// Surface primaire (cartes, panneaux, popovers). Equivalent `surface.primary`.
    public static let surfacePrimary = slateAdaptiveColor(
        light: SlateRGB(hex: "#FFFFFF") ?? .white,
        dark: SlateRGB(hex: "#2A2A2C") ?? .black
    )

    /// Surface secondaire (champs, zones secondaires). Equivalent `surface.secondary`.
    public static let surfaceSecondary = slateAdaptiveColor(
        light: SlateRGB(hex: "#F2F2F5") ?? .white,
        dark: SlateRGB(hex: "#2C2C2E") ?? .black
    )

    /// Surface tertiaire (fonds enfonces/inset). Equivalent `surface.tertiary`.
    public static let surfaceTertiary = slateAdaptiveColor(
        light: SlateRGB(hex: "#E5E5EA") ?? .white,
        dark: SlateRGB(hex: "#3A3A3C") ?? .black
    )

    /// Voile derriere une modale. Equivalent `overlay.scrim`.
    public static let overlayScrim = slateAdaptiveColor(
        light: SlateRGB(red: 0, green: 0, blue: 0, alpha: 0.20),
        dark: SlateRGB(red: 0, green: 0, blue: 0, alpha: 0.45)
    )

    // MARK: - Texte (design/tokens.md §2)

    /// Texte principal. Equivalent `text.primary`.
    public static let textPrimary = slateAdaptiveColor(
        light: SlateRGB(red: 0, green: 0, blue: 0, alpha: 0.85),
        dark: SlateRGB(red: 1, green: 1, blue: 1, alpha: 0.85)
    )

    /// Texte secondaire (metadonnees). Equivalent `text.secondary`.
    ///
    /// Propriete CALCULEE (pas `let`) : elle doit lire l'etat "Increase Contrast" a
    /// chaque acces pour rester reactive (voir `SlateAccessibility.swift`, limite
    /// documentee de `NSColor(name:dynamicProvider:)`). Utilise `textSecondary(increaseContrast:)`
    /// en interne, qui reste testable independamment de `NSWorkspace`.
    public static var textSecondary: Color {
        textSecondary(increaseContrast: slateCurrentlyIncreasesContrast())
    }

    /// Variante pure de `textSecondary`, parametree explicitement par l'etat Increase
    /// Contrast plutot que de lire `NSWorkspace` -- permet de tester la regle
    /// (0,50/0,55 -> 0,72, spec E2) sans dependre de l'environnement systeme reel.
    public static func textSecondary(increaseContrast: Bool) -> Color {
        slateAdaptiveColor(
            light: SlateRGB(
                red: 0,
                green: 0,
                blue: 0,
                alpha: increaseContrast ? SlateTextOpacity.secondaryIncreasedContrast : SlateTextOpacity.secondaryLight
            ),
            dark: SlateRGB(
                red: 1,
                green: 1,
                blue: 1,
                alpha: increaseContrast ? SlateTextOpacity.secondaryIncreasedContrast : SlateTextOpacity.secondaryDark
            )
        )
    }

    /// Texte discret. Equivalent `text.tertiary`.
    public static let textTertiary = slateAdaptiveColor(
        light: SlateRGB(red: 0, green: 0, blue: 0, alpha: 0.26),
        dark: SlateRGB(red: 1, green: 1, blue: 1, alpha: 0.26)
    )

    /// Placeholder. Equivalent `text.placeholder`.
    ///
    /// Propriete CALCULEE (pas `let`) : reste reactive a "Increase Contrast" comme
    /// `textSecondary`/`blockSelectedBackground`.
    ///
    /// CORRIGE en Phase 7 (design/tokens.md §2, artboard P1-K) : 0,25 (valeur des
    /// Phases 1-6) ne composait qu'a 1,83:1 sur `bg.editor` clair, tres sous l'AA --
    /// contrairement a `text.disabled` (reste a 0,25), un placeholder porte une
    /// consigne et doit rester lisible. Nouvelles valeurs 0,55 clair / 0,60 sombre
    /// (4,76:1 / ~6,85:1), 0,70/0,78 sous Increase Contrast (~8,52:1 / ~10,71:1).
    /// Verifie par calcul dans `EditorAccessibilityTests`.
    public static var textPlaceholder: Color {
        slateAdaptiveColor(
            light: SlateRGB(red: 0, green: 0, blue: 0, alpha: SlateTextOpacity.placeholderLight),
            dark: SlateRGB(red: 1, green: 1, blue: 1, alpha: SlateTextOpacity.placeholderDark),
            lightHC: SlateRGB(red: 0, green: 0, blue: 0, alpha: SlateTextOpacity.placeholderLightIncreasedContrast),
            darkHC: SlateRGB(red: 1, green: 1, blue: 1, alpha: SlateTextOpacity.placeholderDarkIncreasedContrast)
        )
    }

    /// Texte desactive. Equivalent `text.disabled`.
    public static let textDisabled = slateAdaptiveColor(
        light: SlateRGB(red: 0, green: 0, blue: 0, alpha: 0.25),
        dark: SlateRGB(red: 1, green: 1, blue: 1, alpha: 0.25)
    )

    /// Texte sur fond d'accent. Equivalent `text.onAccent`.
    ///
    /// Cette constante reste blanche : c'est le fond (`accentSelectionFill`) qui est
    /// ajuste pour garantir l'AA, pas ce texte (voir la note de `ContrastRatio.swift`).
    public static let textOnAccent = Color.white

    /// Texte inverse (tooltips). Equivalent `text.inverse`.
    public static let textInverse = slateAdaptiveColor(
        light: SlateRGB(hex: "#FFFFFF") ?? .white,
        dark: SlateRGB(hex: "#000000") ?? .black
    )

    // MARK: - Accent & etats interactifs (design/tokens.md §3)

    /// Accent principal. Equivalent `accent.default`. A utiliser partout ou l'accent ne
    /// porte PAS de texte (teintes d'icones, anneau de focus, indicateur de depot) : le
    /// seuil AA y est 3:1, `#007AFF`/`#0A84FF` le satisfont deja.
    public static let accentDefault = slateAdaptiveColor(
        light: SlateAccent.defaultLightRGB,
        dark: SlateAccent.defaultDarkRGB
    )

    /// Accent au survol. Equivalent `accent.hover`.
    public static let accentHover = slateAdaptiveColor(
        light: SlateRGB(hex: "#0A6CE0") ?? .black,
        dark: SlateRGB(hex: "#3D9BFF") ?? .black
    )

    /// Accent presse. Equivalent `accent.pressed`.
    public static let accentPressed = slateAdaptiveColor(
        light: SlateRGB(hex: "#0857B8") ?? .black,
        dark: SlateRGB(hex: "#2E7FE0") ?? .black
    )

    /// Fond d'accent atenue. Equivalent `accent.subtle`.
    public static let accentSubtle = slateAdaptiveColor(
        light: SlateRGB(red: 0, green: 122.0 / 255, blue: 255.0 / 255, alpha: 0.12),
        dark: SlateRGB(red: 10.0 / 255, green: 132.0 / 255, blue: 255.0 / 255, alpha: 0.22)
    )

    /// Fond de selection quand la ligne PORTE du texte (ex: libelle de ligne de sidebar,
    /// titre/extrait de cellule de note).
    ///
    /// Token derive, pas une constante : voir la documentation complete dans
    /// `ContrastRatio.swift`. La spec affirmait a tort que `accent.default` atteignait
    /// 4,5:1 avec un libelle blanc (4,55/4,52 annonces vs 3,99/3,65 reels) ; ce token
    /// assombrit l'accent jusqu'a ce que le premier plan LE PLUS EXIGEANT qui s'y pose
    /// reellement (le blanc 95% de l'extrait, spec E3) atteigne l'AA, et le refait
    /// automatiquement si l'accent devient personnalisable (Phase 13) au lieu de
    /// re-introduire le defaut pour chaque nouvel accent.
    ///
    /// Propriete CALCULEE : bascule sur la variante 7:1 quand Increase Contrast est actif
    /// (spec E2 : "7:1 en mode Increase Contrast"). Voir `SlateAccessibility.swift`.
    public static var accentSelectionFill: Color {
        slateCurrentlyIncreasesContrast()
            ? slateAdaptiveColor(
                light: SlateAccent.selectionFillLightRGBIncreasedContrast,
                dark: SlateAccent.selectionFillDarkRGBIncreasedContrast
            )
            : slateAdaptiveColor(
                light: SlateAccent.selectionFillLightRGB,
                dark: SlateAccent.selectionFillDarkRGB
            )
    }

    /// Survol generique. Equivalent `state.hover`.
    public static let stateHover = slateAdaptiveColor(
        light: SlateRGB(red: 0, green: 0, blue: 0, alpha: 0.05),
        dark: SlateRGB(red: 1, green: 1, blue: 1, alpha: 0.07)
    )

    /// Presse generique. Equivalent `state.pressed`.
    public static let statePressed = slateAdaptiveColor(
        light: SlateRGB(red: 0, green: 0, blue: 0, alpha: 0.10),
        dark: SlateRGB(red: 1, green: 1, blue: 1, alpha: 0.12)
    )

    /// Ligne/bloc selectionne, fenetre active. Equivalent `state.selected` (=
    /// `accent.default`, PAS `accentSelectionFill` : ce token est reserve aux blocs qui
    /// ne portent pas de texte directement dessus, ex: bloc selectionne dans l'editeur).
    public static let stateSelected = accentDefault

    /// Selection quand la fenetre est inactive. Equivalent `state.selectedInactive`.
    public static let stateSelectedInactive = slateAdaptiveColor(
        light: SlateRGB(red: 0, green: 0, blue: 0, alpha: 0.10),
        dark: SlateRGB(red: 1, green: 1, blue: 1, alpha: 0.13)
    )

    /// Selection de texte. Equivalent `state.selectedText`.
    public static let stateSelectedText = slateAdaptiveColor(
        light: SlateRGB(red: 0, green: 122.0 / 255, blue: 255.0 / 255, alpha: 0.28),
        dark: SlateRGB(red: 10.0 / 255, green: 132.0 / 255, blue: 255.0 / 255, alpha: 0.35)
    )

    /// Contour de focus clavier. Equivalent `focusRing`.
    public static let focusRing = slateAdaptiveColor(
        light: SlateRGB(red: 0, green: 122.0 / 255, blue: 255.0 / 255, alpha: 0.60),
        dark: SlateRGB(red: 10.0 / 255, green: 132.0 / 255, blue: 255.0 / 255, alpha: 0.65)
    )

    // MARK: - Semantiques (design/tokens.md §4)

    /// Avertissement (spec E3 : etoile de favori, `star.fill = semantic.warning`).
    /// Equivalent `semantic.warning`. Reste 3:1 (seuil glyphe non-textuel), pas 4,5:1 :
    /// jamais utilise seul pour porter une information (spec E3, "Daltonisme" /
    /// "Jamais la couleur seule" -- l'etoile a sa propre forme).
    public static let semanticWarning = slateAdaptiveColor(
        light: SlateRGB(hex: "#FF9500") ?? .black,
        dark: SlateRGB(hex: "#FF9F0A") ?? .black
    )

    // MARK: - Separateurs & bordures (design/tokens.md §5)

    /// Separateur standard. Equivalent `separator`.
    public static let separator = slateAdaptiveColor(
        light: SlateRGB(red: 0, green: 0, blue: 0, alpha: 0.10),
        dark: SlateRGB(red: 1, green: 1, blue: 1, alpha: 0.15)
    )

    /// Bordure de champs/cartes. Equivalent `border.default`.
    public static let borderDefault = slateAdaptiveColor(
        light: SlateRGB(red: 0, green: 0, blue: 0, alpha: 0.12),
        dark: SlateRGB(red: 1, green: 1, blue: 1, alpha: 0.15)
    )

    /// Bordure accentuee. Equivalent `border.strong`.
    public static let borderStrong = slateAdaptiveColor(
        light: SlateRGB(red: 0, green: 0, blue: 0, alpha: 0.22),
        dark: SlateRGB(red: 1, green: 1, blue: 1, alpha: 0.28)
    )

    // MARK: - Tokens barre laterale (design/tokens.md §17)

    /// En-tetes de section (11 pt Semibold majuscules). Equivalent `sidebar.sectionHeader.text`.
    public static let sidebarSectionHeaderText = slateAdaptiveColor(
        light: SlateRGB(red: 0, green: 0, blue: 0, alpha: 0.45),
        dark: SlateRGB(red: 1, green: 1, blue: 1, alpha: 0.45)
    )

    /// Chevron de pliage. Equivalent `sidebar.chevron` (= `text.tertiary`).
    public static let sidebarChevron = textTertiary

    /// Fond d'une ligne survolee. Equivalent `sidebar.item.hover.bg` (= `state.hover`).
    public static let sidebarItemHoverBackground = stateHover

    // MARK: - Premier plan sur aplat d'accent

    /// Couleur de premier plan a utiliser pour TOUT contenu (icone, glyphe, texte) pose
    /// sur `accentSelectionFill` (= la pastille de selection active). Alias de
    /// `textOnAccent` sous un nom generique : ce token ne parle pas que de texte, il sert
    /// aussi aux icones (chevron, icone de dossier, etoile de favori...) qui doivent
    /// suivre la meme regle (spec E2, icone de dossier : "teinte = couleur du dossier ;
    /// passe en blanc sur selection active"). Voir `foreground(_:onAccentFill:)` pour la
    /// facon recommandee de le consommer depuis un composant.
    public static let foregroundOnAccentFill = textOnAccent

    /// Choisit entre `base` et `foregroundOnAccentFill` selon que le contenu est
    /// actuellement pose sur l'aplat d'accent de selection (`EnvironmentValues.slateIsOnAccentFill`).
    ///
    /// Point d'entree unique recommande pour tout composant qui doit rester lisible a la
    /// fois hors selection (sa teinte habituelle, `base`) et sur la selection active
    /// (bascule automatique en blanc/`text.onAccent`). Exemple :
    /// ```swift
    /// @Environment(\.slateIsOnAccentFill) private var isOnAccentFill
    /// ...
    /// .foregroundStyle(SlateColor.foreground(SlateColor.textTertiary, onAccentFill: isOnAccentFill))
    /// ```
    public static func foreground(_ base: Color, onAccentFill isOnAccentFill: Bool) -> Color {
        isOnAccentFill ? foregroundOnAccentFill : base
    }

    /// Premier plan SECONDAIRE a utiliser sur `accentSelectionFill` (spec E3 : l'extrait
    /// de la cellule de note, "blanc 95%"). Distinct de `foregroundOnAccentFill` (le
    /// premier plan PRINCIPAL, blanc opaque) : la spec cree une hierarchie a deux niveaux
    /// sur la selection, et c'est CE token, le plus exigeant des deux, qui contraint le
    /// calcul de `accentSelectionFill` (voir `SlateAccent.selectionForegroundSecondary`).
    public static let foregroundSecondaryOnAccentFill = Color.white.opacity(0.95)

    /// Choisit entre `base` et `foregroundSecondaryOnAccentFill` selon
    /// `EnvironmentValues.slateIsOnAccentFill`. Pendant de `foreground(_:onAccentFill:)`
    /// pour le contenu SECONDAIRE (extrait, metadonnee) plutot que principal (titre).
    public static func foregroundSecondary(_ base: Color, onAccentFill isOnAccentFill: Bool) -> Color {
        isOnAccentFill ? foregroundSecondaryOnAccentFill : base
    }
}
