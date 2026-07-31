import SwiftUI
import SlateUI

/// Placeholder de la colonne detail (editeur) du `NavigationSplitView`.
///
/// Phase 1 : contenu vide, aucune fonctionnalite. Le vrai editeur de blocs arrive en
/// Phase 5 (docs/05_editeur_blocs.md) dans le module `SlateEditor`.
struct NoteDetailPlaceholderView: View {
    var body: some View {
        ContentUnavailableView(
            String(localized: "noteDetail.placeholder.title", defaultValue: "Sélectionnez une note"),
            systemImage: "doc.text",
            description: Text(
                String(
                    localized: "noteDetail.placeholder.description",
                    defaultValue: "Le contenu de la note sélectionnée apparaîtra ici."
                )
            )
        )
        .padding(Spacing.md)
    }
}

#Preview {
    NoteDetailPlaceholderView()
}
