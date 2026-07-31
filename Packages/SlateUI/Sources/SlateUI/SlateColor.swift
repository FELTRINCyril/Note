import AppKit
import SwiftUI

/// Cree une couleur adaptative clair/sombre a partir de deux `SlateRGB`, via
/// `NSColor(name:dynamicProvider:)`. Suit automatiquement l'apparence de la fenetre
/// (donc aussi "Increase Contrast" si `NSAppearance` bascule sur un des deux cas de
/// base geres ici -- clair/sombre uniquement, cf. limite documentee sur `SlateColor`).
private func slateAdaptiveColor(light: SlateRGB, dark: SlateRGB) -> Color {
    Color(nsColor: NSColor(name: nil) { appearance in
        let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let rgb = isDark ? dark : light
        return NSColor(red: rgb.red, green: rgb.green, blue: rgb.blue, alpha: rgb.alpha)
    })
}

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

    /// Accent clair assombri jusqu'a 4,5:1 avec un libelle blanc. Ordre de grandeur
    /// attendu (voir `ContrastRatio.swift`) : proche de `#0071ED` (~4,58:1).
    public static let selectionFillLightRGB = WCAGContrast.darkening(
        defaultLightRGB,
        toReachContrast: 4.5,
        with: .white
    )

    /// Accent sombre assombri jusqu'a 4,5:1 avec un libelle blanc. Ordre de grandeur
    /// attendu : proche de `#0975E3` (~4,50:1).
    public static let selectionFillDarkRGB = WCAGContrast.darkening(
        defaultDarkRGB,
        toReachContrast: 4.5,
        with: .white
    )
}

/// Tokens de couleur semantiques de Slate, alignes sur `design/tokens.md` (§1 a §8) et
/// sur `design/03_sidebar/Slate_E1-E2_coquille-sidebar.html` (Specifications E1/E2).
///
/// Toutes les couleurs sont adaptatives clair/sombre (`NSColor(name:dynamicProvider:)`) :
/// aucune vue ne doit tester `colorScheme` elle-meme pour choisir une teinte.
///
/// Limite connue : la valeur "Increase Contrast" mentionnee dans la spec ("les rangs
/// secondaires sont renforces en mode Increase Contrast (0,50 -> 0,72)") n'est pas
/// encore implementee ici -- `NSAppearance.bestMatch` ne distingue que clair/sombre, pas
/// le contraste augmente. A traiter si Cyril le demande explicitement (pas dans le
/// perimetre de cette phase).
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
    public static let textSecondary = slateAdaptiveColor(
        light: SlateRGB(red: 0, green: 0, blue: 0, alpha: 0.50),
        dark: SlateRGB(red: 1, green: 1, blue: 1, alpha: 0.55)
    )

    /// Texte discret. Equivalent `text.tertiary`.
    public static let textTertiary = slateAdaptiveColor(
        light: SlateRGB(red: 0, green: 0, blue: 0, alpha: 0.26),
        dark: SlateRGB(red: 1, green: 1, blue: 1, alpha: 0.26)
    )

    /// Placeholder. Equivalent `text.placeholder`.
    public static let textPlaceholder = slateAdaptiveColor(
        light: SlateRGB(red: 0, green: 0, blue: 0, alpha: 0.25),
        dark: SlateRGB(red: 1, green: 1, blue: 1, alpha: 0.25)
    )

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

    /// Fond de selection quand la ligne PORTE du texte (ex: libelle de ligne de sidebar).
    ///
    /// Token derive, pas une constante : voir la documentation complete dans
    /// `ContrastRatio.swift`. La spec affirmait a tort que `accent.default` atteignait
    /// 4,5:1 avec un libelle blanc (4,55/4,52 annonces vs 4,02/3,65 reels) ; ce token
    /// assombrit l'accent jusqu'a atteindre reellement l'AA (~4,58:1 clair, ~4,50:1
    /// sombre), et le refait automatiquement si l'accent devient personnalisable
    /// (Phase 13) au lieu de re-introduire le defaut pour chaque nouvel accent.
    public static let accentSelectionFill = slateAdaptiveColor(
        light: SlateAccent.selectionFillLightRGB,
        dark: SlateAccent.selectionFillDarkRGB
    )

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
}

/// Opacites transverses (design/tokens.md §14).
public enum SlateOpacity {
    /// Element desactive.
    public static let disabled: Double = 0.4
    /// Survol generique quand exprime en opacite plutot qu'en couleur rgba.
    public static let hoverOverlay: Double = 0.06
    /// Aperçu ("ghost") d'une ligne en cours de glissement.
    public static let dragGhost: Double = 0.6
}

/// Palette d'icones de dossiers/notes (design/tokens.md §7/§8). Reprend les couleurs
/// d'accent systeme macOS ; le jaune est la couleur de dossier par defaut (façon Notes).
///
/// Ce token ne decide PAS la couleur du texte/icone quand la ligne est selectionnee
/// (passage en blanc) : c'est a l'appelant (`SidebarRow` et ses utilisateurs) de choisir
/// entre `.color` et `SlateColor.textOnAccent` selon l'etat de selection.
public enum SlateFolderColor: String, CaseIterable, Sendable {
    case blue
    case violet
    case rose
    case red
    case orange
    case yellow
    case green
    case graphite

    private var rgb: (light: SlateRGB, dark: SlateRGB) {
        switch self {
        case .blue:
            (SlateRGB(hex: "#007AFF") ?? .black, SlateRGB(hex: "#0A84FF") ?? .black)
        case .violet:
            (SlateRGB(hex: "#AF52DE") ?? .black, SlateRGB(hex: "#BF5AF2") ?? .black)
        case .rose:
            (SlateRGB(hex: "#FF2D55") ?? .black, SlateRGB(hex: "#FF375F") ?? .black)
        case .red:
            (SlateRGB(hex: "#FF3B30") ?? .black, SlateRGB(hex: "#FF453A") ?? .black)
        case .orange:
            (SlateRGB(hex: "#FF9500") ?? .black, SlateRGB(hex: "#FF9F0A") ?? .black)
        case .yellow:
            (SlateRGB(hex: "#FFCC00") ?? .black, SlateRGB(hex: "#FFD60A") ?? .black)
        case .green:
            (SlateRGB(hex: "#34C759") ?? .black, SlateRGB(hex: "#30D158") ?? .black)
        case .graphite:
            (SlateRGB(hex: "#8E8E93") ?? .black, SlateRGB(hex: "#98989D") ?? .black)
        }
    }

    /// Couleur adaptative clair/sombre de ce dossier, hors etat de selection.
    public var color: Color {
        slateAdaptiveColor(light: rgb.light, dark: rgb.dark)
    }
}
