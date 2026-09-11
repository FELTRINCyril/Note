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
            HStack(spacing: Spacing.xs) {
                // Cadenas (Phase 12, `docs/12_verrouillage.md` : "indicateur dans la liste
                // ET la barre laterale"). Ne revele jamais rien du contenu -- seul
                // `note.isLocked`, un booleen, est lu ici.
                if note.isLocked {
                    Image(systemName: "lock.fill")
                        .slateIconFont(SlateGeometry.sidebarBadgeIconSize, relativeTo: .subheadline)
                        .foregroundStyle(SlateColor.foreground(SlateColor.textSecondary, onAccentFill: isOnAccentFill))
                }
                Image(systemName: "star.fill")
                    .slateIconFont(SlateGeometry.sidebarBadgeIconSize, relativeTo: .subheadline)
                    .foregroundStyle(SlateColor.foreground(SlateFolderColor.yellow.color, onAccentFill: isOnAccentFill))
            }
        }
        .accessibilityLabel(accessibilityLabelText)
    }

    private var accessibilityLabelText: String {
        let base = String(
            format: String(localized: "sidebar.favorites.accessibilityLabel", bundle: .module),
            displayTitle
        )
        guard note.isLocked else { return base }
        let lockedSuffix = String(localized: "noteList.cell.accessibility.locked", bundle: .module)
        return "\(base), \(lockedSuffix)"
    }

    private var displayTitle: String {
        note.title.isEmpty ? String(localized: "sidebar.favorites.untitled", bundle: .module) : note.title
    }
}
