import SlateModel
import SlateUI
import SwiftUI

/// Point d'entree de la base PLEINE PAGE (Phase 17, "les deux hebergements" :
/// `Database.hostMode == .fullPage`, rattachee a un `Folder` via `Folder.databases`) :
/// section compacte en tete de la colonne du milieu (`NoteListView`), au meme niveau que
/// la liste des notes du dossier. Au plus simple deliberement (le coordinateur ne demande
/// pas une navigation elaboree, juste un point d'acces) : une ligne par base existante +
/// une ligne "+ Nouvelle base".
struct DatabaseFolderSectionView: View {
    let databases: [Database]
    let selectedDatabaseID: UUID?
    let onSelect: (Database) -> Void
    let onCreate: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ListSectionHeader(String(localized: "database.folderSection.title", bundle: .module))
            ForEach(databases) { database in
                row(for: database)
            }
            Button(action: onCreate) {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "plus")
                        .slateIconFont(12, weight: .semibold, relativeTo: .callout)
                    Text(String(localized: "database.folderSection.new", bundle: .module))
                }
                .slateFont(SlateFont.label)
                .foregroundStyle(SlateColor.textSecondary)
                .padding(.horizontal, SlateGeometry.noteCellPaddingHorizontal)
                .padding(.vertical, Spacing.sm)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(localized: "database.folderSection.new", bundle: .module))

            Rectangle()
                .fill(SlateColor.separator)
                .frame(height: SlateGeometry.strokeHairline)
        }
    }

    private func row(for database: Database) -> some View {
        let isSelected = database.id == selectedDatabaseID
        return Button {
            onSelect(database)
        } label: {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "tablecells")
                    .slateIconFont(SlateGeometry.sidebarIconSize)
                    .foregroundStyle(SlateColor.textSecondary)
                Text(database.name.isEmpty ? String(localized: "database.untitled", bundle: .module) : database.name)
                    .slateFont(isSelected ? SlateFont.bodyEmphasis : SlateFont.body)
                    .foregroundStyle(SlateColor.textPrimary)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, SlateGeometry.noteCellPaddingHorizontal)
            .padding(.vertical, Spacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? SlateColor.stateHover : Color.clear)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}
