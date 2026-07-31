import SwiftUI
import SlateModel
import SlateUI

/// Ligne d'une note favorite dans la section "Favoris" de la sidebar.
///
/// Volontairement minimale (titre + etoile) : la richesse d'une cellule de note
/// (extrait, date...) est celle de la Phase 4 (liste de notes), hors perimetre de
/// cette phase. Non interactive : la selection de note et l'ouverture dans l'editeur
/// arrivent avec les Phases 4/5 ; construire une interaction qui ne mene nulle part
/// donnerait une fausse promesse de fonctionnalite.
struct FavoriteNoteRow: View {
    let note: Note

    @Environment(\.slateIsOnAccentFill) private var isOnAccentFill

    var body: some View {
        SidebarRow(title: displayTitle) {
            Image(systemName: "star.fill")
                .slateIconFont(SlateGeometry.sidebarBadgeIconSize, relativeTo: .subheadline)
                .foregroundStyle(SlateColor.foreground(SlateFolderColor.yellow.color, onAccentFill: isOnAccentFill))
        }
        .accessibilityLabel(
            String(
                format: String(localized: "sidebar.favorites.accessibilityLabel", bundle: .module),
                displayTitle
            )
        )
    }

    private var displayTitle: String {
        note.title.isEmpty ? String(localized: "sidebar.favorites.untitled", bundle: .module) : note.title
    }
}
