import SlateModel
import SlateUI
import SwiftUI

/// Vue Galerie (17.5) : une `DatabaseGalleryCardView` par ligne, memes lignes filtrees/
/// triees que les autres vues. Sans piece jointe image dans le modele de base de
/// donnees a ce jour, chaque carte affiche le cadre "Sans apercu" natif du composant
/// (voir sa documentation : "jamais la premiere image du corps, trop imprevisible" -
/// principe qui s'applique tout autant a l'absence totale de source d'image ici).
struct DatabaseGalleryView: View {
    @Bindable var viewModel: DatabaseViewModel

    private let columns = [GridItem(.adaptive(minimum: 200), spacing: Spacing.md)]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: Spacing.md) {
                ForEach(viewModel.visibleRows) { row in
                    DatabaseGalleryCardView(
                        title: title(row),
                        pill: pill(row),
                        metaText: metaText(row),
                        thumbnailSize: viewModel.galleryThumbnailSize
                    ) { EmptyView() }
                        .contextMenu {
                            Button(role: .destructive) { viewModel.deleteRow(row.id) } label: {
                                Label(
                                    String(localized: "database.grid.deleteRow", bundle: .module),
                                    systemImage: "trash"
                                )
                            }
                        }
                }
            }
            .padding(Spacing.lg)
        }
        .background(SlateColor.bgEditor)
    }

    private func title(_ row: DatabaseRowSnapshot) -> String {
        guard let field = viewModel.snapshot.fields.first(where: { $0.type == .text }) else {
            return String(localized: "database.kanban.untitledCard", bundle: .module)
        }
        return DatabaseCellFormatting.displayText(row.values[field.id], field: field)
            ?? String(localized: "database.kanban.untitledCard", bundle: .module)
    }

    private func pill(_ row: DatabaseRowSnapshot) -> (title: String, style: SlateDatabasePillStyle)? {
        guard let field = viewModel.snapshot.fields.first(where: { $0.type == .singleSelect }) else { return nil }
        return DatabaseCellFormatting.tags(for: row.values[field.id], field: field).first
    }

    private func metaText(_ row: DatabaseRowSnapshot) -> String? {
        guard let field = viewModel.snapshot.fields.first(where: { $0.type == .date }) else { return nil }
        return DatabaseCellFormatting.displayText(row.values[field.id], field: field)
    }
}
