import SwiftUI

/// Fantome de bloc en cours de glissement (design/tokens.md §13/§14, artboard I de
/// `Slate P1 - Formatage & blocs.dc.html` : "copie du bloc a `opacity.dragGhost` 0.6,
/// `elevation.high`, rotation -1 deg [...] Badge de comptage si plusieurs blocs").
///
/// Neutre quant au CONTENU du bloc (`SlateUI` ne connait ni `Block` ni `Note`, meme
/// contrat que `BlockContainer`/`ColumnsBlockView`) : `content` recoit un apercu deja
/// mis en forme par l'appelant (`SlateEditor`), pas un modele de bloc.
///
/// Le SUIVI du curseur (position, retard de 40 ms annonce par l'artboard) est laisse a
/// l'appelant : cette vue ne fait que dessiner le chrome visuel du fantome a l'endroit
/// ou on la place, elle n'a pas d'opinion sur le systeme de coordonnees de
/// `SlateEditor` (`NoteDocumentView.blockListCoordinateSpace`).
public struct BlockDragGhostView<Content: View>: View {
    /// Nombre de blocs deplaces. Le badge de comptage n'apparait qu'a partir de 2 --
    /// meme regle que `BlockDropIndicatorView` (Phase 9) : "avec un seul bloc, aucun
    /// badge, le fantome suffit a lui seul".
    private let blockCount: Int
    private let content: Content

    public init(blockCount: Int = 1, @ViewBuilder content: () -> Content) {
        self.blockCount = blockCount
        self.content = content()
    }

    public var body: some View {
        content
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: SlateGeometry.radiusMedium)
                    .fill(SlateColor.bgEditor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: SlateGeometry.radiusMedium)
                    .strokeBorder(SlateColor.separator, lineWidth: SlateGeometry.strokeHairline)
            )
            .shadow(
                color: SlateColor.elevationHighShadow,
                radius: SlateGeometry.dragGhostShadowRadius,
                y: SlateGeometry.dragGhostShadowY
            )
            .rotationEffect(.degrees(SlateGeometry.dragGhostRotationDegrees))
            .opacity(SlateOpacity.dragGhost)
            .overlay(alignment: .topTrailing) {
                if blockCount >= 2 {
                    countBadge
                }
            }
            // Le fantome suit le curseur pendant un glisser purement a la souris :
            // aucune information supplementaire pour VoiceOver, qui suit deja
            // l'equivalent clavier obligatoire (Ctrl+Cmd+fleches, artboard I) via ses
            // propres annonces ("deplace en position 2 sur 5") -- exposees par
            // l'appelant, pas par cette vue de pur rendu.
            .accessibilityHidden(true)
    }

    private var countBadge: some View {
        Text("\(blockCount)")
            .slateFont(SlateFont.caption)
            .foregroundStyle(SlateColor.foregroundOnAccentFill)
            .frame(width: SlateGeometry.dragGhostBadgeSize, height: SlateGeometry.dragGhostBadgeSize)
            .background(Circle().fill(SlateColor.accentDefault))
            .offset(x: SlateGeometry.dragGhostBadgeSize / 2, y: -SlateGeometry.dragGhostBadgeSize / 2)
    }
}

public extension View {
    /// Bloc d'ORIGINE pendant un glisser-depose (artboard I : "reste en place a 40 %
    /// tant que le depot n'est pas valide"). A appliquer par l'appelant sur le
    /// `BlockContainer` du/des blocs effectivement en train d'etre deplaces -- jamais
    /// sur `BlockDragGhostView` lui-meme, qui porte deja sa propre opacite
    /// (`opacity.dragGhost`, distincte).
    func slateDragSourceBlockAppearance() -> some View {
        opacity(SlateOpacity.dragSourceBlock)
    }
}

#Preview("BlockDragGhostView - un bloc, clair") {
    ZStack(alignment: .topLeading) {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("Le chrome de bloc reste dans la gouttiere pendant le glisser.")
            Text("Le bloc d'origine reste en place tant que le depot n'est pas valide.")
                .slateDragSourceBlockAppearance()
        }
        .slateFont(SlateFont.body)
        .foregroundStyle(SlateColor.textPrimary)
        .frame(width: 500, alignment: .leading)

        BlockDragGhostView {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "line.3.horizontal")
                    .slateIconFont(SlateGeometry.blockHandleGlyphSize, weight: .medium)
                    .foregroundStyle(SlateColor.textTertiary)
                Text("Le bloc d'origine reste en place...")
                    .slateFont(SlateFont.body)
                    .foregroundStyle(SlateColor.textPrimary)
            }
        }
        .offset(x: 150, y: 90)
    }
    .padding(Spacing.lg)
    .frame(width: 640, height: 220)
    .background(SlateColor.bgEditor)
    .environment(\.colorScheme, .light)
}

#Preview("BlockDragGhostView - multi-blocs (badge 2), sombre") {
    ZStack(alignment: .topLeading) {
        BlockDragGhostView(blockCount: 2) {
            Text("Chantiers Q3 (2 blocs)")
                .slateFont(SlateFont.body)
                .foregroundStyle(SlateColor.textPrimary)
        }
        .offset(x: 60, y: 40)
    }
    .padding(Spacing.lg)
    .frame(width: 420, height: 160)
    .background(SlateColor.bgEditor)
    .environment(\.colorScheme, .dark)
}

#Preview("BlockContainer - ligne verticale de depot lateral (colonne), sombre") {
    BlockContainer(dropEdge: .trailing, blockID: "cible") {
        Text("Bloc cible, survole sur son tiers droit.")
            .slateFont(SlateFont.body)
            .foregroundStyle(SlateColor.textPrimary)
    }
    .padding(Spacing.lg)
    .frame(width: 560, height: 140)
    .background(SlateColor.bgEditor)
    .environment(\.colorScheme, .dark)
}
