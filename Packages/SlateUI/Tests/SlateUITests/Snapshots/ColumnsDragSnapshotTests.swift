import Testing
import SwiftUI
@testable import SlateUI

/// Verification visuelle du glisser-depose et des colonnes (Phase 10, design/
/// tokens.md §13/§14, artboard I de `Slate P1 - Formatage & blocs.dc.html`) : fantome de
/// glisser (bloc unique et multi-blocs), indicateurs de depot (ligne entre blocs,
/// frontiere laterale de colonne) -- clair ET sombre.
@MainActor
@Suite("Verification visuelle - colonnes et glisser (Phase 10)")
struct ColumnsDragSnapshotTests {
    @Test("Fantome de glisser - un bloc et multi-blocs, clair et sombre")
    func dragGhost() throws {
        for scheme in ColorScheme.allCases {
            try SnapshotRenderer.render(
                singleBlockGhost.environment(\.colorScheme, scheme),
                named: "columns_drag_ghost_single_\(scheme.snapshotSuffix)"
            )
            try SnapshotRenderer.render(
                multiBlockGhost.environment(\.colorScheme, scheme),
                named: "columns_drag_ghost_multi_\(scheme.snapshotSuffix)"
            )
        }
    }

    @Test("Indicateur de depot entre blocs (1 et 3 fichiers), clair et sombre")
    func dropIndicatorLine() throws {
        for scheme in ColorScheme.allCases {
            let single = VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Le curseur survole la frontiere entre deux paragraphes.")
                BlockDropIndicatorView(fileCount: 1)
                Text("Meme ligne d'insertion que pour le deplacement de blocs.")
            }
            .slateFont(SlateFont.body)
            .foregroundStyle(SlateColor.textPrimary)
            .padding()
            .frame(width: 480)
            .background(SlateColor.bgEditor)
            .environment(\.colorScheme, scheme)

            try SnapshotRenderer.render(single, named: "columns_drop_indicator_single_\(scheme.snapshotSuffix)")

            let multi = BlockDropIndicatorView(fileCount: 3, itemLabel: "images")
                .padding()
                .frame(width: 480)
                .background(SlateColor.bgEditor)
                .environment(\.colorScheme, scheme)

            try SnapshotRenderer.render(multi, named: "columns_drop_indicator_multi_\(scheme.snapshotSuffix)")
        }
    }

    @Test("Indicateur de depot lateral (frontiere de colonne), clair et sombre")
    func columnDropEdge() throws {
        for scheme in ColorScheme.allCases {
            let view = BlockContainer(dropEdge: .trailing, blockID: "cible") {
                Text("Bloc cible, survole sur son tiers droit.")
                    .slateFont(SlateFont.body)
                    .foregroundStyle(SlateColor.textPrimary)
            }
            .padding(Spacing.lg)
            .frame(width: 560, height: 140)
            .background(SlateColor.bgEditor)
            .environment(\.colorScheme, scheme)

            try SnapshotRenderer.render(view, named: "columns_drop_edge_\(scheme.snapshotSuffix)")
        }
    }

    private var singleBlockGhost: some View {
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
    }

    private var multiBlockGhost: some View {
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
    }
}
