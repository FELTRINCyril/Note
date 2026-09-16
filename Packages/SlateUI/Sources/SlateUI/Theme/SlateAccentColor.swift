import SwiftUI

/// Les 8 accents personnalisables proposes par Slate (design/tokens.md §7 -- reprend les
/// couleurs d'accent systeme macOS). `.blue` est la valeur par defaut.
///
/// Type pur (pas de dependance a `ThemeManager` ni a AppKit) : tous les calculs de
/// contraste ci-dessous sont testables independamment de l'etat courant de l'app. C'est
/// `ThemeManager.accent` qui porte le CHOIX courant ; `SlateColor`/`SlateSemanticColors`
/// lisent ce choix (via `slateCurrentAccent()`) puis delegue le calcul a ce type.
public enum SlateAccentColor: String, CaseIterable, Sendable, Equatable, Identifiable {
    case blue
    case purple
    case pink
    case red
    case orange
    case yellow
    case green
    case graphite

    public var id: String { rawValue }

    /// Aplat clair (design/tokens.md §7).
    public var lightRGB: SlateRGB {
        switch self {
        case .blue: SlateRGB(hex: "#007AFF") ?? .black
        case .purple: SlateRGB(hex: "#AF52DE") ?? .black
        case .pink: SlateRGB(hex: "#FF2D55") ?? .black
        case .red: SlateRGB(hex: "#FF3B30") ?? .black
        case .orange: SlateRGB(hex: "#FF9500") ?? .black
        case .yellow: SlateRGB(hex: "#FFCC00") ?? .black
        case .green: SlateRGB(hex: "#34C759") ?? .black
        case .graphite: SlateRGB(hex: "#8E8E93") ?? .black
        }
    }

    /// Aplat sombre (design/tokens.md §7).
    public var darkRGB: SlateRGB {
        switch self {
        case .blue: SlateRGB(hex: "#0A84FF") ?? .black
        case .purple: SlateRGB(hex: "#BF5AF2") ?? .black
        case .pink: SlateRGB(hex: "#FF375F") ?? .black
        case .red: SlateRGB(hex: "#FF453A") ?? .black
        case .orange: SlateRGB(hex: "#FF9F0A") ?? .black
        case .yellow: SlateRGB(hex: "#FFD60A") ?? .black
        case .green: SlateRGB(hex: "#30D158") ?? .black
        case .graphite: SlateRGB(hex: "#98989D") ?? .black
        }
    }

    /// Nom affiche au survol / lu par VoiceOver ("Bleu, selectionne" -- artboard B du
    /// design P4). Localise (FR + EN) via `Bundle.module` depuis la dette technique de
    /// fin de jalon v1 -- `SlateUI` declare desormais son propre catalogue, voir
    /// `Package.swift` et `SlateUIStrings`.
    public var displayName: String {
        SlateUIStrings.accentDisplayName(self)
    }

    // MARK: - `text.onAccent` (design/tokens.md §7, correction Phase 13)

    /// Vrai quand `text.onAccent`, pour cet accent et ce theme, doit etre du noir 85 %
    /// plutot que du blanc (table mesuree de `design/tokens.md` §7). Le graphite est le
    /// seul cas ou le theme sombre est PLUS exigeant que le clair (3,03:1 en blanc contre
    /// 6,17:1 en noir).
    public func usesDarkOnAccentText(dark: Bool) -> Bool {
        switch self {
        case .orange, .yellow, .green: true
        case .graphite: dark
        case .blue, .purple, .pink, .red: false
        }
    }

    /// Premier plan a poser sur l'aplat plein de cet accent (checkbox cochee, badge,
    /// bouton plein...). Fonction de l'accent ET du theme -- voir `usesDarkOnAccentText`.
    public func onAccentRGB(dark: Bool) -> SlateRGB {
        usesDarkOnAccentText(dark: dark) ? SlateAccentColor.onAccentBlack : .white
    }

    /// Noir 85 % utilise comme `text.onAccent` sur les teintes claires (orange, jaune,
    /// vert) et sur le graphite sombre.
    private static let onAccentBlack = SlateRGB(red: 0, green: 0, blue: 0, alpha: 0.85)

    /// Vrai pour les quatre teintes dont le blanc reste entre 3,0 et 4,2:1 sur l'aplat de
    /// base (design/tokens.md §7, "ecart assume") -- celles que "Augmenter le contraste"
    /// assombrit de 12 % pour repasser au-dessus de l'AA texte (4,5:1).
    public var hasLowContrastOnAccentText: Bool {
        switch self {
        case .blue, .purple, .pink, .red: true
        case .orange, .yellow, .green, .graphite: false
        }
    }

    /// Aplat effectif de l'accent compte tenu de "Augmenter le contraste" : assombri pour
    /// les quatre teintes basses jusqu'a ce que le blanc (leur `onAccentRGB`) atteigne au
    /// moins 4,5:1 (design/tokens.md §7 evoque un assombrissement "de 12 %" donnant
    /// bleu 4,71 / violet 4,68 / rose 4,83 / rouge 4,60:1 -- notre calcul, voir le rapport
    /// de livraison, converge vers un facteur tres proche mais pas identique a 12 % au
    /// point pres ; on redemande l'AA plutot que de reproduire un pourcentage fixe, pour
    /// rester correct quels que soient les arrondis de l'accent). Inchange pour les
    /// quatre autres teintes (deja au-dessus de l'AA avec leur `onAccentRGB`).
    public func fillRGB(dark: Bool, increasedContrast: Bool) -> SlateRGB {
        let base = dark ? darkRGB : lightRGB
        guard increasedContrast, hasLowContrastOnAccentText else { return base }
        return WCAGContrast.darkening(base, toReachContrast: 4.5, with: .white)
    }

    // MARK: - Etats interactifs derives (hover / pressed / subtle)

    /// Accent au survol (design/tokens.md §3 : plus sombre en clair, plus clair en sombre
    /// -- comportement observe sur le bleu par defaut, reproduit ici pour les 8 accents).
    public func hoverRGB(dark: Bool) -> SlateRGB {
        dark ? Self.blended(darkRGB, towardWhite: 0.22) : Self.scaled(lightRGB, brightness: 0.88)
    }

    /// Accent presse (plus sombre dans les deux themes).
    public func pressedRGB(dark: Bool) -> SlateRGB {
        Self.scaled(dark ? darkRGB : lightRGB, brightness: dark ? 0.88 : 0.72)
    }

    /// Fond d'accent attenue (design/tokens.md §3 : alpha 0,12 en clair, 0,22 en sombre).
    public func subtleRGB(dark: Bool) -> SlateRGB {
        (dark ? darkRGB : lightRGB).withAlpha(dark ? 0.22 : 0.12)
    }

    // MARK: - `text.link` derive de l'accent (design/tokens.md §7, correction Phase 13)

    /// Fond de l'editeur, seul repere fixe necessaire au calcul de `text.link` : un accent
    /// pose EN TEXTE doit rester lisible sur `bg.editor` (design/tokens.md §1).
    private static let editorBackgroundLightRGB = SlateRGB(hex: "#FFFFFF") ?? .white
    private static let editorBackgroundDarkRGB = SlateRGB(hex: "#1C1C1E") ?? .black

    /// Variante de l'accent utilisable EN TEXTE sur `bg.editor` (`text.link` et toute
    /// application de l'accent en texte, design/tokens.md, "Couleur de texte derivee de
    /// l'accent"). Assombrie en clair, eclaircie en sombre, jusqu'a l'AA texte (4,5:1) --
    /// l'accent brut peut tomber tres bas (vert clair #34C759 = 2,0:1 sur fond blanc).
    public func linkRGB(dark: Bool) -> SlateRGB {
        dark
            ? WCAGContrast.lightening(darkRGB, toReachContrast: 4.5, with: Self.editorBackgroundDarkRGB)
            : WCAGContrast.darkening(lightRGB, toReachContrast: 4.5, with: Self.editorBackgroundLightRGB)
    }

    // MARK: - Libelle de pastille (Phase 17, design/tokens.md §18)

    /// Variante de l'accent utilisable EN TEXTE sur SON PROPRE fond `.subtle`
    /// (`DatabasePillView`, statut/etiquette d'une base de donnees) -- DISTINCTE de
    /// `linkRGB` : `accent.subtle` compose sur `bg.editor` reste tres proche du blanc/
    /// noir pur, mais suffisamment different pour que `linkRGB` (calibre sur `bg.editor`
    /// lui-meme) retombe sous l'AA une fois pose sur ce fond legerement teinte (mesure
    /// dans `DatabaseContrastTests` : jusqu'a 3,02:1 en sombre). Meme methode que
    /// `linkRGB` (assombrissement/eclaircissement jusqu'a 4,5:1), mais la cible du calcul
    /// est le fond REELLEMENT porte (`accent.subtle` compose sur `bg.editor`), pas
    /// `bg.editor` seul.
    public func pillLabelRGB(dark: Bool) -> SlateRGB {
        let backdrop = dark ? Self.editorBackgroundDarkRGB : Self.editorBackgroundLightRGB
        let ownBackground = WCAGContrast.compositeOverBackground(subtleRGB(dark: dark), backdrop)
        return dark
            ? WCAGContrast.lightening(darkRGB, toReachContrast: 4.5, with: ownBackground)
            : WCAGContrast.darkening(lightRGB, toReachContrast: 4.5, with: ownBackground)
    }

    // MARK: - Ajustements de luminosite (purs, sans alpha-blending)

    /// Multiplie les trois composantes RGB par `factor` (assombrissement HSB a teinte/
    /// saturation constantes -- meme principe que `WCAGContrast.darkening`).
    private static func scaled(_ rgb: SlateRGB, brightness factor: Double) -> SlateRGB {
        SlateRGB(red: rgb.red * factor, green: rgb.green * factor, blue: rgb.blue * factor, alpha: rgb.alpha)
    }

    /// Melange `rgb` vers le blanc dans la proportion `factor` (0 = inchange, 1 = blanc
    /// pur) : eclaircissement utilise pour le survol en theme sombre.
    private static func blended(_ rgb: SlateRGB, towardWhite factor: Double) -> SlateRGB {
        SlateRGB(
            red: rgb.red + (1 - rgb.red) * factor,
            green: rgb.green + (1 - rgb.green) * factor,
            blue: rgb.blue + (1 - rgb.blue) * factor,
            alpha: rgb.alpha
        )
    }
}
