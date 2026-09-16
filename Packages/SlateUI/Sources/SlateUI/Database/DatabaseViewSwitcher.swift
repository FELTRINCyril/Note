import SwiftUI

/// Les 5 vues d'une base de donnees (design/tokens.md §18, barre commune a toutes les
/// pages de l'artboard A : "onglets de vue a gauche").
public enum SlateDatabaseViewKind: String, Sendable, Equatable, CaseIterable, Identifiable {
    case grid
    case kanban
    case calendar
    case gallery
    case list

    public var id: String { rawValue }

    /// Glyphe SF Symbols le plus proche des icones dessinees a la main dans le design
    /// (tableau/kanban/calendrier/grille/lignes).
    public var systemImage: String {
        switch self {
        case .grid: "tablecells"
        case .kanban: "rectangle.split.3x1"
        case .calendar: "calendar"
        case .gallery: "square.grid.2x2"
        case .list: "list.bullet"
        }
    }
}

/// Selecteur de vue : 5 onglets, l'actif porte un fond `state.hover`-like (le design
/// utilise un aplat neutre `rgba(0,0,0,0.10)`, distinct de `state.hover` -- reutilise
/// `surface.tertiary`, meme famille de gris, pas une nouvelle teinte).
public struct DatabaseViewSwitcher: View {
    private let selection: SlateDatabaseViewKind
    private let titles: [SlateDatabaseViewKind: String]
    private let onSelect: (SlateDatabaseViewKind) -> Void

    public init(
        selection: SlateDatabaseViewKind,
        titles: [SlateDatabaseViewKind: String],
        onSelect: @escaping (SlateDatabaseViewKind) -> Void
    ) {
        self.selection = selection
        self.titles = titles
        self.onSelect = onSelect
    }

    public var body: some View {
        HStack(spacing: 2) {
            ForEach(SlateDatabaseViewKind.allCases) { kind in
                tab(kind)
            }
        }
    }

    private func tab(_ kind: SlateDatabaseViewKind) -> some View {
        let isSelected = kind == selection
        return Button {
            onSelect(kind)
        } label: {
            HStack(spacing: Spacing.xs) {
                Image(systemName: kind.systemImage)
                    .slateIconFont(13, relativeTo: .subheadline)
                Text(titles[kind] ?? kind.rawValue)
            }
            .slateFont(isSelected ? SlateFont.bodyEmphasis : SlateFont.label)
            .foregroundStyle(isSelected ? SlateColor.textPrimary : SlateColor.textSecondary)
            .padding(.horizontal, Spacing.sm)
            .frame(height: 26)
            .background(isSelected ? SlateColor.surfaceTertiary : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: SlateGeometry.radiusSmall))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

#Preview("DatabaseViewSwitcher - clair") {
    DatabaseViewSwitcherPreview()
        .environment(\.colorScheme, .light)
}

#Preview("DatabaseViewSwitcher - sombre") {
    DatabaseViewSwitcherPreview()
        .environment(\.colorScheme, .dark)
}

private struct DatabaseViewSwitcherPreview: View {
    @State private var selection: SlateDatabaseViewKind = .grid

    var body: some View {
        DatabaseViewSwitcher(
            selection: selection,
            titles: [.grid: "Grille", .kanban: "Kanban", .calendar: "Calendrier", .gallery: "Galerie", .list: "Liste"]
        ) { selection = $0 }
            .padding(Spacing.md)
            .background(SlateColor.bgEditor)
    }
}
