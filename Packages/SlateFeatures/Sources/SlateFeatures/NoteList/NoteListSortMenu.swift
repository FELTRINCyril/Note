import SwiftUI
import SlateModel
import SlateUI

/// Menu de tri de la liste de notes (spec E3, "Menu de tri" : "Picker inline (Date de
/// modification - Date de creation - Titre) + interrupteur 'Ordre croissant'. Le
/// libelle VoiceOver du bouton annonce le tri courant ; l'icone seule ne porte pas
/// l'information.").
///
/// Le bouton lui-meme (icone seule visuellement) porte donc systematiquement un
/// `accessibilityLabel` ET un `.help` decrivant le tri COURANT ("Date de modification,
/// decroissant"), pas seulement le nom du controle ("Trier") : un utilisateur
/// VoiceOver doit savoir ou en est le tri sans ouvrir le menu.
struct NoteListSortMenu: View {
    @Binding var criterion: NoteSortCriterion
    @Binding var direction: SortDirection

    var body: some View {
        Menu {
            Picker(String(localized: "noteList.sort.criterionPickerLabel", bundle: .module), selection: $criterion) {
                Text(String(localized: "noteList.sort.criterion.modifiedDate", bundle: .module))
                    .tag(NoteSortCriterion.modifiedDate)
                Text(String(localized: "noteList.sort.criterion.createdDate", bundle: .module))
                    .tag(NoteSortCriterion.createdDate)
                Text(String(localized: "noteList.sort.criterion.title", bundle: .module))
                    .tag(NoteSortCriterion.title)
            }
            .pickerStyle(.inline)

            Toggle(String(localized: "noteList.sort.ascendingToggle", bundle: .module), isOn: isAscendingBinding)
        } label: {
            Image(systemName: "arrow.up.arrow.down")
                .slateIconFont(SlateGeometry.toolbarIconSize, relativeTo: .subheadline)
        }
        .menuIndicator(.hidden)
        .help(currentSortDescription)
        .accessibilityLabel(currentSortDescription)
    }

    private var isAscendingBinding: Binding<Bool> {
        Binding(
            get: { direction == .ascending },
            set: { isAscending in direction = isAscending ? .ascending : .descending }
        )
    }

    private var criterionDescription: String {
        switch criterion {
        case .modifiedDate:
            String(localized: "noteList.sort.criterion.modifiedDate", bundle: .module)
        case .createdDate:
            String(localized: "noteList.sort.criterion.createdDate", bundle: .module)
        case .title:
            String(localized: "noteList.sort.criterion.title", bundle: .module)
        }
    }

    private var directionDescription: String {
        direction == .ascending
            ? String(localized: "noteList.sort.direction.ascending", bundle: .module)
            : String(localized: "noteList.sort.direction.descending", bundle: .module)
    }

    private var currentSortDescription: String {
        let template = String(localized: "noteList.sort.button.accessibilityLabel", bundle: .module)
        return String(format: template, criterionDescription, directionDescription)
    }
}

#Preview("NoteListSortMenu") {
    NoteListSortMenuPreview()
        .padding()
        .background(SlateColor.bgList)
}

private struct NoteListSortMenuPreview: View {
    @State private var criterion: NoteSortCriterion = .modifiedDate
    @State private var direction: SortDirection = .descending

    var body: some View {
        NoteListSortMenu(criterion: $criterion, direction: $direction)
    }
}
