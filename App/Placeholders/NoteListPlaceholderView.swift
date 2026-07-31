import SwiftUI
import SlateUI

/// Placeholder de la colonne liste (colonne centrale) du `NavigationSplitView`.
///
/// Phase 1 : contenu vide, aucune fonctionnalite. La vraie liste de notes arrive en
/// Phase 4 (docs/04_liste_notes.md) dans le module `SlateFeatures`.
struct NoteListPlaceholderView: View {
    var body: some View {
        ContentUnavailableView(
            String(localized: "noteList.placeholder.title", defaultValue: "Notes"),
            systemImage: "note.text",
            description: Text(
                String(
                    localized: "noteList.placeholder.description",
                    defaultValue: "Les notes du dossier sélectionné apparaîtront ici."
                )
            )
        )
        .padding(Spacing.md)
    }
}

#Preview {
    NoteListPlaceholderView()
}
