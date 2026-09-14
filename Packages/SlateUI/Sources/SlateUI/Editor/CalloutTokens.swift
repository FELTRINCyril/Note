import SwiftUI

/// Variantes de callout (design/tokens.md §16 bis, artboard F de
/// `Slate P1 - Formatage & blocs.dc.html`, Phase 8).
///
/// Les `semantic.*` de §4 (`SlateColor.semanticWarning`...) restent valides pour une
/// ICONE ou un APLAT, mais poses EN TEXTE sur leur propre fond atenue ils tombent a
/// 2,0-3,5:1 (voir §16 bis) : chaque variante porte donc sa propre couleur de libelle,
/// mesuree sur son propre fond. Le CORPS d'un callout reste toujours `text.primary`
/// (artboard F : "seule l'icone et le libelle de variante sont teintes").
///
/// Les composantes RGB brutes (`backgroundLightRGB`...) sont exposees separement des
/// `Color` adaptatives, meme motif que `SlateHighlightToken`/`SlateBlockSelection` :
/// elles restent mesurables par `WCAGContrast` sans dependre du rendu SwiftUI.
public enum SlateCalloutVariant: String, CaseIterable, Identifiable, Sendable {
    case neutral
    case info
    case warning
    case success

    public var id: String { rawValue }

    /// `callout.bg`. La variante neutre reutilise `surface.secondary` (design/tokens.md
    /// §16 : "variantes = `semantic.*` en `.subtle`" pour les 3 autres).
    var backgroundLightRGB: SlateRGB {
        switch self {
        case .neutral: SlateRGB(hex: "#F2F2F5") ?? .white
        case .info: SlateRGB(hex: "#E5F1FF") ?? .white
        case .warning: SlateRGB(hex: "#FFF4E5") ?? .white
        case .success: SlateRGB(hex: "#EAF9EE") ?? .white
        }
    }

    var backgroundDarkRGB: SlateRGB {
        switch self {
        case .neutral: SlateRGB(hex: "#2C2C2E") ?? .black
        case .info: SlateRGB(hex: "#1B2A3A") ?? .black
        case .warning: SlateRGB(hex: "#3A2E1A") ?? .black
        case .success: SlateRGB(hex: "#1F3D27") ?? .black
        }
    }

    /// Couleur du libelle de variante ET de l'icone (design/tokens.md §16 bis). La
    /// variante neutre reprend `text.secondary` (0,50 clair / 0,55 sombre, sur noir/blanc
    /// purs pour rester une constante mesurable independamment de "Increase Contrast").
    var labelLightRGB: SlateRGB {
        switch self {
        case .neutral: SlateRGB(red: 0, green: 0, blue: 0, alpha: SlateTextOpacity.secondaryLight)
        case .info: SlateRGB(hex: "#05509E") ?? .black
        case .warning: SlateRGB(hex: "#9A5700") ?? .black
        case .success: SlateRGB(hex: "#1E7A34") ?? .black
        }
    }

    var labelDarkRGB: SlateRGB {
        switch self {
        case .neutral: SlateRGB(red: 1, green: 1, blue: 1, alpha: SlateTextOpacity.secondaryDark)
        case .info: SlateRGB(hex: "#6CB6FF") ?? .white
        case .warning: SlateRGB(hex: "#FF9F0A") ?? .white
        case .success: SlateRGB(hex: "#30D158") ?? .white
        }
    }

    /// `callout.bg` adaptatif clair/sombre.
    public var background: Color { slateAdaptiveColor(light: backgroundLightRGB, dark: backgroundDarkRGB) }

    /// `callout.border`, commun aux 4 variantes.
    public var border: Color { SlateColor.calloutBorder }

    /// Couleur adaptative du libelle de variante et de l'icone.
    public var labelColor: Color { slateAdaptiveColor(light: labelLightRGB, dark: labelDarkRGB) }

    /// Libelle textuel de la variante : l'information n'est jamais portee par la seule
    /// couleur (`nil` pour la variante neutre, qui n'a pas de libelle, artboard F).
    public var label: String? {
        switch self {
        case .neutral: nil
        case .info: SlateUIStrings.calloutInfo
        case .warning: SlateUIStrings.calloutWarning
        case .success: SlateUIStrings.calloutSuccess
        }
    }

    /// Glyphe SF Symbols par defaut. La variante neutre affiche une icone LIBRE choisie
    /// par l'utilisateur dans le vrai editeur (artboard F) ; ce symbole n'est qu'un
    /// repli provisoire pour les previews et les callouts neutres sans icone choisie.
    public var symbol: String {
        switch self {
        case .neutral: "pin.fill"
        case .info: "info.circle"
        case .warning: "exclamationmark.triangle"
        case .success: "checkmark.circle"
        }
    }
}
