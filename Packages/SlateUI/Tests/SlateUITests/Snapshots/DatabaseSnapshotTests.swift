import Testing
import SwiftUI
@testable import SlateUI

/// Verification visuelle des bases de donnees (Phase 17, `Slate P5 - Bases de
/// donnees.dc.html`) : cellules de chaque type, en-tete de colonne, cellule de calcul,
/// carte/colonne Kanban, carte de galerie, ligne de liste, pastilles, bascule de vues,
/// jour de calendrier -- clair ET sombre.
@MainActor
@Suite("Verification visuelle - bases de donnees (Phase 17)")
struct DatabaseSnapshotTests {
    @Test("Cellules de grille (une ligne de chaque type), clair et sombre")
    func gridCells() throws {
        for scheme in ColorScheme.allCases {
            try SnapshotRenderer.render(
                cellRow.environment(\.colorScheme, scheme),
                named: "database_cells_\(scheme.snapshotSuffix)"
            )
        }
    }

    @Test("Chrome de grille - en-tete, poignee, ajout de ligne, cellules de calcul, clair et sombre")
    func gridChrome() throws {
        for scheme in ColorScheme.allCases {
            try SnapshotRenderer.render(
                GridChromeGallery().environment(\.colorScheme, scheme),
                named: "database_grid_chrome_\(scheme.snapshotSuffix)"
            )
        }
    }

    @Test("Colonne et carte Kanban, clair et sombre")
    func kanban() throws {
        for scheme in ColorScheme.allCases {
            try SnapshotRenderer.render(
                kanbanColumn.environment(\.colorScheme, scheme),
                named: "database_kanban_\(scheme.snapshotSuffix)"
            )
        }
    }

    @Test("Carte de galerie et ligne de liste, clair et sombre")
    func galleryAndList() throws {
        for scheme in ColorScheme.allCases {
            try SnapshotRenderer.render(
                galleryAndListGallery.environment(\.colorScheme, scheme),
                named: "database_gallery_list_\(scheme.snapshotSuffix)"
            )
        }
    }

    @Test("Pastilles (pleines et compactes), clair et sombre")
    func pills() throws {
        for scheme in ColorScheme.allCases {
            try SnapshotRenderer.render(
                pillGallery.environment(\.colorScheme, scheme),
                named: "database_pills_\(scheme.snapshotSuffix)"
            )
        }
    }

    @Test("Bascule de vues, clair et sombre")
    func viewSwitcher() throws {
        for scheme in ColorScheme.allCases {
            try SnapshotRenderer.render(
                DatabaseViewSwitcherGallery().environment(\.colorScheme, scheme),
                named: "database_view_switcher_\(scheme.snapshotSuffix)"
            )
        }
    }

    @Test("Grille de calendrier (mois), clair et sombre")
    func calendar() throws {
        for scheme in ColorScheme.allCases {
            try SnapshotRenderer.render(
                calendarGallery.environment(\.colorScheme, scheme),
                named: "database_calendar_\(scheme.snapshotSuffix)"
            )
        }
    }

    private var cellRow: some View {
        HStack(spacing: 0) {
            DatabaseGridCell { DatabaseTextCellView("Editeur de blocs") }
                .frame(width: 220)
            DatabaseGridCell {
                DatabasePillView("En cours", style: SlateDatabasePillStyle(accent: .blue, bullet: .square))
            }
            .frame(width: 130)
            DatabaseGridCell { DatabasePersonCellView(name: "Camille", initials: "CM", accent: .purple) }
                .frame(width: 150)
            DatabaseGridCell { DatabaseDateCellView("12 sept. 2026") }
                .frame(width: 130)
            DatabaseGridCell { DatabaseProgressCellView(fraction: 0.72, percentText: "72 %") }
                .frame(width: 130)
            DatabaseGridCell(showsTrailingBorder: false) {
                DatabaseTagsCellView(tags: [
                    ("v1", SlateDatabasePillStyle(accent: .purple)),
                    ("bloquant", SlateDatabasePillStyle(accent: .orange))
                ])
            }
        }
        .background(SlateColor.bgEditor)
    }

    private var kanbanColumn: some View {
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

    private var galleryAndListGallery: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            HStack(spacing: Spacing.md) {
                DatabaseGalleryCardView(
                    title: "Editeur de blocs",
                    pill: ("En cours", SlateDatabasePillStyle(accent: .blue, bullet: .square)),
                    metaText: "Camille - 12 sept."
                ) { EmptyView() }
                DatabaseGalleryCardView(
                    title: "Assistant IA",
                    pill: ("A faire", SlateDatabasePillStyle(accent: nil, bullet: .hollowCircle))
                ) { EmptyView() }
            }
            .frame(width: 420)

            VStack(spacing: 0) {
                ListSectionHeader("Camille", count: 2)
                DatabaseListRowView(
                    title: "Editeur de blocs",
                    pill: ("En cours", SlateDatabasePillStyle(accent: .blue, bullet: .square)),
                    trailingText: "12 sept."
                )
                DatabaseListRowView(
                    title: "Verrouillage de notes",
                    pill: ("Livre", SlateDatabasePillStyle(accent: .green, bullet: .check)),
                    trailingText: "3 sept."
                )
            }
            .frame(width: 420)
        }
        .padding(Spacing.lg)
        .background(SlateColor.bgEditor)
    }

    private var pillGallery: some View {
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

    private var calendarGallery: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            DatabaseCalendarNavigationBar(title: "Septembre 2026", onPrevious: {}, onToday: {}, onNext: {})
            DatabaseCalendarMonthGridView(
                weekdaySymbols: ["L", "M", "M", "J", "V", "S", "D"],
                days: (1...28).map { number in
                    SlateDatabaseCalendarDay(
                        id: number,
                        dayNumber: number,
                        isInCurrentMonth: true,
                        isToday: number == 12,
                        eventTitles: number == 12 ? ["Editeur de blocs"] : []
                    )
                }
            )
        }
        .padding(Spacing.lg)
        .frame(width: 480)
        .background(SlateColor.bgEditor)
    }
}

private struct GridChromeGallery: View {
    @State private var width: CGFloat = 150

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 0) {
                DatabaseColumnHeaderCell(title: "Chantier", systemImage: "text.alignleft")
                DatabaseColumnHeaderCell(
                    title: "Statut",
                    systemImage: "circle",
                    sortDirection: .ascending,
                    showsMenuGlyph: true
                )
                .frame(width: width)
                DatabaseColumnResizeHandle(width: $width)
            }
            DatabaseAddRowButton(title: "Nouvelle fiche") {}
            HStack(spacing: 0) {
                DatabaseCalculationCell(resultText: "6 fiches", showsTrailingBorder: true) {}
                DatabaseCalculationCell(resultText: "Moyenne : 54 %", isEmphasized: true) {}
                DatabaseCalculationCell(resultText: nil, showsTrailingBorder: false) {}
            }
        }
        .frame(width: 520)
        .background(SlateColor.bgEditor)
    }
}

private struct DatabaseViewSwitcherGallery: View {
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
