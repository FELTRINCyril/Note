import SwiftUI

/// Vue Kanban (design/tokens.md §18, artboard B). Composants de PRESENTATION purs :
/// `SlateUI` ne connait ni le champ de groupement ni les fiches reelles.

/// Colonne de groupe Kanban : en-tete (puce + titre + compteur) + cartes + bouton
/// d'ajout. `content` rend l'empilement des cartes -- l'appelant (`SlateFeatures`)
/// decide de leur ordre et de leur gestion du glisser-depose (via `.draggable`/
/// `.dropDestination` sur chaque carte, ce composant ne fait qu'offrir le fond).
public struct DatabaseKanbanColumnView<Content: View>: View {
    private let title: String
    private let count: Int
    private let pillStyle: SlateDatabasePillStyle
    private let content: Content

    public init(
        title: String,
        count: Int,
        pillStyle: SlateDatabasePillStyle,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.count = count
        self.pillStyle = pillStyle
        self.content = content()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.xs) {
                bullet
                Text(title)
                    .slateFont(SlateFont.bodyEmphasis)
                    .foregroundStyle(SlateColor.textPrimary)
                Spacer(minLength: Spacing.xs)
                Text(count, format: .number)
                    .slateFont(SlateFont.sidebarCounter)
                    .foregroundStyle(SlateColor.textSecondary)
            }
            content
        }
        .padding(Spacing.md)
        .frame(minWidth: SlateGeometry.databaseKanbanColumnMinWidth, maxWidth: .infinity, alignment: .top)
        .background(SlateColor.databaseKanbanColumnBackground)
        .clipShape(RoundedRectangle(cornerRadius: SlateGeometry.radiusMedium))
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder private var bullet: some View {
        let size = SlateGeometry.databaseStatusBulletSize
        switch pillStyle.bullet {
        case .none: EmptyView()
        case .square: Rectangle().fill(pillStyle.foreground).frame(width: size, height: size)
        case .hollowCircle:
            Circle().strokeBorder(pillStyle.foreground, lineWidth: SlateGeometry.strokeHairline * 1.5)
                .frame(width: size, height: size)
        case .check:
            Image(systemName: "checkmark").slateIconFont(size, weight: .heavy, relativeTo: .caption)
                .foregroundStyle(pillStyle.foreground)
        }
    }
}

/// Carte Kanban : titre + etiquettes + pied (avatar/date/avancement, artboard B).
/// `isDragging` applique l'opacite d'origine (`slateDragSourceBlockAppearance`,
/// reutilisee telle quelle) ; l'appelant enveloppe le FANTOME de glissement dans
/// `BlockDragGhostView` (Phase 9/10), pas un composant dedie ici -- ce dernier est deja
/// generique quant au contenu.
public struct DatabaseKanbanCardView<Footer: View>: View {
    private let title: String
    private let tags: [(title: String, style: SlateDatabasePillStyle)]
    private let isDragging: Bool
    private let footer: Footer

    public init(
        title: String,
        tags: [(title: String, style: SlateDatabasePillStyle)] = [],
        isDragging: Bool = false,
        @ViewBuilder footer: () -> Footer = { EmptyView() }
    ) {
        self.title = title
        self.tags = tags
        self.isDragging = isDragging
        self.footer = footer()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(title)
                .slateFont(SlateFont.bodyEmphasis)
                .foregroundStyle(SlateColor.textPrimary)
            if !tags.isEmpty {
                HStack(spacing: Spacing.xs) {
                    ForEach(Array(tags.enumerated()), id: \.offset) { _, tag in
                        DatabasePillView(tag.title, style: tag.style, isCompact: true)
                    }
                }
            }
            footer
        }
        .padding(Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(SlateColor.databaseCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: SlateGeometry.radiusMedium))
        .shadow(
            color: SlateColor.databaseCardShadow,
            radius: SlateGeometry.databaseCardShadowRadius,
            y: SlateGeometry.databaseCardShadowY
        )
        .opacity(isDragging ? SlateOpacity.dragSourceBlock : 1)
        .accessibilityElement(children: .combine)
    }
}

#Preview("DatabaseKanbanColumnView - clair") {
    DatabaseKanbanGalleryPreview()
        .environment(\.colorScheme, .light)
}

#Preview("DatabaseKanbanColumnView - sombre") {
    DatabaseKanbanGalleryPreview()
        .environment(\.colorScheme, .dark)
}

private struct DatabaseKanbanGalleryPreview: View {
    var body: some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            DatabaseKanbanColumnView(
                title: "A faire",
                count: 2,
                pillStyle: SlateDatabasePillStyle(accent: nil, bullet: .hollowCircle)
            ) {
                VStack(spacing: Spacing.sm) {
                    DatabaseKanbanCardView(
                        title: "Assistant IA - RAG",
                        tags: [("v2", SlateDatabasePillStyle(accent: .pink))]
                    ) {
                        Text("Non attribue")
                            .slateFont(SlateFont.caption)
                            .foregroundStyle(SlateColor.textSecondary)
                    }
                    DatabaseKanbanCardView(title: "Partage de note", isDragging: true) {
                        Text("Nadia - 14 nov.")
                            .slateFont(SlateFont.caption)
                            .foregroundStyle(SlateColor.textSecondary)
                    }
                }
            }
        }
        .padding(Spacing.lg)
        .frame(width: 320)
        .background(SlateColor.bgEditor)
    }
}
