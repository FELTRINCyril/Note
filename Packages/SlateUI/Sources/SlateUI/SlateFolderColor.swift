import SwiftUI

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
