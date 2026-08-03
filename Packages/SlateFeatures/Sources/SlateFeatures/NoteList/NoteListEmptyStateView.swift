import SwiftUI
import SlateUI

/// Les DEUX etats vides DISTINCTS de la spec E3 ("Etats vides") : "Aucune note" (le
/// dossier selectionne ne contient reellement aucune note, hors de toute recherche -
/// action "Nouvelle note" disponible) et "Aucun resultat" (le dossier contient des
/// notes mais la recherche en cours n'en trouve aucune - bouton "Rechercher partout"
/// affiche mais explicitement DESACTIVE plutot que de feindre un comportement non
/// cable en Phase 4 : la recherche multi-dossiers n'existe pas avant la Phase 15, la
/// regle d'honnetete d'interface du projet interdit de laisser croire le contraire).
///
/// S'appuie sur `ContentUnavailableView` (comme `NoteListColumnPlaceholderView`/
/// `NoteDetailColumnPlaceholderView` avant elle) plutot que de composer une mise en
/// page a la main : `ContentUnavailableView` gere deja elle-meme le dimensionnement de
/// son icone et l'espacement de son contenu, sans qu'aucun literal de police/espacement
/// n'ait besoin d'etre ecrit ici - `SlateUI` n'expose d'ailleurs aucun token pour une
/// icone d'etat vide de cette taille (36 pt dans la maquette).
struct NoteListEmptyStateView: View {
    enum Kind {
        case noNotes(folderName: String, onCreateNote: () -> Void)
        case noResults(query: String, folderName: String)
    }

    let kind: Kind

    var body: some View {
        switch kind {
        case .noNotes(let folderName, let onCreateNote):
            ContentUnavailableView {
                Label(String(localized: "noteList.empty.noNotes.title", bundle: .module), systemImage: "note.text")
            } description: {
                Text(noNotesDescription(folderName: folderName))
            } actions: {
                Button(String(localized: "noteList.empty.noNotes.newNoteButton", bundle: .module), action: onCreateNote)
            }
        case .noResults(let query, let folderName):
            let searchEverywhereHelp = String(
                localized: "noteList.empty.noResults.searchEverywhereHelp",
                bundle: .module
            )
            ContentUnavailableView {
                Label(
                    String(localized: "noteList.empty.noResults.title", bundle: .module),
                    systemImage: "magnifyingglass"
                )
            } description: {
                Text(noResultsDescription(query: query, folderName: folderName))
            } actions: {
                Button(String(localized: "noteList.empty.noResults.searchEverywhereButton", bundle: .module)) {}
                    .disabled(true)
                    .help(searchEverywhereHelp)
                    .accessibilityHint(searchEverywhereHelp)
            }
        }
    }

    private func noNotesDescription(folderName: String) -> String {
        let template = String(localized: "noteList.empty.noNotes.description", bundle: .module)
        return String(format: template, folderName)
    }

    private func noResultsDescription(query: String, folderName: String) -> String {
        let template = String(localized: "noteList.empty.noResults.description", bundle: .module)
        return String(format: template, query, folderName)
    }
}

#Preview("NoteListEmptyStateView - aucune note") {
    NoteListEmptyStateView(kind: .noNotes(folderName: "Specifications", onCreateNote: {}))
        .frame(width: 300, height: 260)
        .background(SlateColor.bgList)
}

#Preview("NoteListEmptyStateView - aucun resultat") {
    NoteListEmptyStateView(kind: .noResults(query: "stencil", folderName: "Specifications"))
        .frame(width: 300, height: 260)
        .background(SlateColor.bgList)
}
