import SwiftUI

/// Forme de puce d'un statut/etiquette (design/tokens.md §18, artboard A : "chaque
/// option porte une forme de puce en plus de sa couleur -- carre, rond creux, coche --
/// l'etat ne depend jamais de la seule couleur").
public enum SlateDatabasePillBullet: String, Sendable, Equatable, CaseIterable {
    /// Aucune puce (etiquette simple, sans notion de progression).
    case none
    /// Puce carree pleine (ex: "En cours").
    case square
    /// Puce ronde creuse (ex: "A faire").
    case hollowCircle
    /// Coche (ex: "Livre").
    case check
}

/// Style visuel d'une pastille de statut/etiquette : un accent (`nil` = variante
/// neutre grise, ex: "securite") + une forme de puce optionnelle.
public struct SlateDatabasePillStyle: Sendable, Equatable {
    public let accent: SlateAccentColor?
    public let bullet: SlateDatabasePillBullet

    public init(accent: SlateAccentColor?, bullet: SlateDatabasePillBullet = .none) {
        self.accent = accent
        self.bullet = bullet
    }

    /// `db.tag.bg` : teinte `.subtle` de l'accent (design/tokens.md §7/§18), ou
    /// `databaseNeutralPillBackground` pour la variante neutre.
    var background: Color {
        guard let accent else { return SlateColor.databaseNeutralPillBackground }
        return slateAdaptiveColor(light: accent.subtleRGB(dark: false), dark: accent.subtleRGB(dark: true))
    }

    /// Le libelle et la puce prennent la variante LISIBLE de l'accent, calculee pour
    /// SON PROPRE fond `.subtle` (`SlateAccentColor.pillLabelRGB`, design "Couleur de
    /// texte derivee de l'accent", §18 : "le texte de l'etiquette prend donc la
    /// variante lisible... pas la couleur vive") -- DISTINCT de `linkRGB` (calibre sur
    /// `bg.editor` seul, insuffisant une fois pose sur le fond teinte de la pastille,
    /// voir `DatabaseContrastTests`).
    var foreground: Color {
        guard let accent else { return SlateColor.databaseNeutralPillLabel }
        return slateAdaptiveColor(light: accent.pillLabelRGB(dark: false), dark: accent.pillLabelRGB(dark: true))
    }
}

/// Pastille de statut/etiquette (vue Grille/Kanban/Galerie/Liste + editeur de champ +
/// template, design/tokens.md §18). Composant de PRESENTATION pur : le libelle et le
/// style sont fournis par l'appelant, qui seul connait le champ de selection reel.
///
/// `isCompact` reduit la hauteur (18 pt au lieu de 20, artboards B/D : cartes Kanban et
/// template de fiche) sans changer la police -- meme densite que le reste de ces
/// contextes.
public struct DatabasePillView: View {
    private let title: String
    private let style: SlateDatabasePillStyle
    private let isCompact: Bool

    public init(_ title: String, style: SlateDatabasePillStyle, isCompact: Bool = false) {
        self.title = title
        self.style = style
        self.isCompact = isCompact
    }

    public var body: some View {
        HStack(spacing: Spacing.xs) {
            bullet
            Text(title)
                .slateFont(SlateFont.caption)
                .foregroundStyle(style.foreground)
        }
        .padding(.horizontal, Spacing.sm)
        .frame(height: isCompact ? SlateGeometry.databaseTagPillHeightCompact : SlateGeometry.databaseTagPillHeight)
        .background(Capsule().fill(style.background))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
    }

    @ViewBuilder private var bullet: some View {
        let size = SlateGeometry.databaseStatusBulletSize
        switch style.bullet {
        case .none:
            EmptyView()
        case .square:
            Rectangle()
                .fill(style.foreground)
                .frame(width: size, height: size)
        case .hollowCircle:
            Circle()
                .strokeBorder(style.foreground, lineWidth: SlateGeometry.strokeHairline * 1.5)
                .frame(width: size, height: size)
        case .check:
            Image(systemName: "checkmark")
                .slateIconFont(size, weight: .heavy, relativeTo: .caption)
                .foregroundStyle(style.foreground)
        }
    }
}

#Preview("DatabasePillView - statuts, clair") {
    DatabasePillGalleryPreview()
        .environment(\.colorScheme, .light)
}

#Preview("DatabasePillView - statuts, sombre") {
    DatabasePillGalleryPreview()
        .environment(\.colorScheme, .dark)
}

private struct DatabasePillGalleryPreview: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            DatabasePillView("A faire", style: SlateDatabasePillStyle(accent: nil, bullet: .hollowCircle))
            DatabasePillView("En cours", style: SlateDatabasePillStyle(accent: .blue, bullet: .square))
            DatabasePillView("Livre", style: SlateDatabasePillStyle(accent: .green, bullet: .check))
            HStack(spacing: Spacing.xs) {
                DatabasePillView("v1", style: SlateDatabasePillStyle(accent: .purple), isCompact: true)
                DatabasePillView("bloquant", style: SlateDatabasePillStyle(accent: .orange), isCompact: true)
                DatabasePillView("securite", style: SlateDatabasePillStyle(accent: nil), isCompact: true)
            }
        }
        .padding(Spacing.lg)
        .frame(width: 320)
        .background(SlateColor.bgEditor)
    }
}
