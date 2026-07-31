import SwiftUI
import SlateUI

/// Placeholder de la colonne detail (editeur, Phase 5).
///
/// Respecte quand meme la regle de coquille de la spec E1 : la largeur de la colonne
/// de texte est plafonnee a `SlateGeometry.editorMaxContentWidth` (720 pt) et
/// centree, meme si le contenu n'est qu'un message d'attente.
struct NoteDetailColumnPlaceholderView: View {
    var body: some View {
        HStack(spacing: 0) {
            Spacer(minLength: 0)
            ContentUnavailableView(
                String(localized: "noteDetail.placeholder.title", bundle: .module),
                systemImage: "doc.text",
                description: Text(String(localized: "noteDetail.placeholder.description", bundle: .module))
            )
            .frame(maxWidth: SlateGeometry.editorMaxContentWidth)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(SlateColor.bgEditor)
    }
}

#Preview("NoteDetailColumnPlaceholderView - clair") {
    NoteDetailColumnPlaceholderView()
}

#Preview("NoteDetailColumnPlaceholderView - sombre") {
    NoteDetailColumnPlaceholderView()
        .preferredColorScheme(.dark)
}
