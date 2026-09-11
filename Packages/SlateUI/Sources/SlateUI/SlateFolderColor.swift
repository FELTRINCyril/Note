import SwiftUI

/// Opacites transverses (design/tokens.md §14).
public enum SlateOpacity {
    /// Element desactive.
    public static let disabled: Double = 0.4
    /// Survol generique quand exprime en opacite plutot qu'en couleur rgba.
    public static let hoverOverlay: Double = 0.06
    /// Aperçu ("ghost") d'une ligne en cours de glissement.
    public static let dragGhost: Double = 0.6

    /// Bloc d'origine pendant un glisser-depose (artboard I : "reste en place a 40 %
    /// tant que le depot n'est pas valide"). Alias explicite de `disabled` : meme
    /// valeur numerique par coincidence, pas une parente semantique (meme convention
    /// que `listMarkerWidth`/`blockHandleSize` dans `BlockDecorationMetrics`).
    public static let dragSourceBlock: Double = disabled

    /// Fond du badge circulaire de `DeletePermanentlyConfirmationOverlay` (design P3,
    /// artboard B : `rgba(255,59,48,0.12)` derriere l'icone de corbeille).
    public static let badgeSubtleFill: Double = 0.12

    /// Aplat d'un bouton plein pendant l'appui (design P3 : bouton "Supprimer").
    public static let pressedFill: Double = 0.85
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

    /// Delegue au type qui porte desormais ces 8 teintes en SOURCE UNIQUE (Phase 13,
    /// accent personnalisable) : `SlateFolderColor` et `SlateAccentColor` couvraient la
    /// meme palette (design/tokens.md §7/§8) avec deux jeux de constantes hex dupliques
    /// (violet/rose ici, purple/pink cote accent -- memes valeurs, noms differents).
    /// CORRIGE en Phase 13 pour eliminer ce risque de desynchronisation.
    private var accent: SlateAccentColor {
        switch self {
        case .blue: .blue
        case .violet: .purple
        case .rose: .pink
        case .red: .red
        case .orange: .orange
        case .yellow: .yellow
        case .green: .green
        case .graphite: .graphite
        }
    }

    /// Couleur adaptative clair/sombre de ce dossier, hors etat de selection.
    public var color: Color { accent.color }
}
