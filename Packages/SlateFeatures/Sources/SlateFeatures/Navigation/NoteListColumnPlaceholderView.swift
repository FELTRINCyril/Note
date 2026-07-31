import SwiftUI
import SlateModel
import SlateUI

/// Placeholder de la colonne du milieu (liste de notes, Phase 4).
///
/// Prouve la cascade de selection demandee par le critere d'acceptation
/// ("Selectionner un dossier change bien la colonne du milieu") sans coder la vraie
/// liste : affiche le nom et le nombre de notes du dossier selectionne, ou un etat
/// vide explicite si aucun dossier n'est selectionne.
struct NoteListColumnPlaceholderView: View {
    let selectedFolder: Folder?

    var body: some View {
        if let folder = selectedFolder {
            ContentUnavailableView {
                Label(folder.name, systemImage: folder.iconName)
            } description: {
                Text(folderNoteCountText(folder.noteCount))
            }
        } else {
            ContentUnavailableView(
                String(localized: "noteList.placeholder.title", bundle: .module),
                systemImage: "note.text",
                description: Text(String(localized: "noteList.placeholder.description", bundle: .module))
            )
        }
    }

    private func folderNoteCountText(_ count: Int) -> String {
        switch count {
        case 0:
            String(localized: "noteList.placeholder.folderEmpty", bundle: .module)
        case 1:
            String(localized: "noteList.placeholder.folderOneNote", bundle: .module)
        default:
            String(format: String(localized: "noteList.placeholder.folderManyNotes", bundle: .module), count)
        }
    }
}

#Preview("NoteListColumnPlaceholderView - sans selection") {
    NoteListColumnPlaceholderView(selectedFolder: nil)
}
