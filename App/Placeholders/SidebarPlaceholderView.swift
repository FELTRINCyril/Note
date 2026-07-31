import SwiftUI
import SlateUI

/// Placeholder de la colonne sidebar (barre laterale) du `NavigationSplitView`.
///
/// Phase 1 : contenu vide, aucune fonctionnalite. La vraie barre laterale
/// (workspaces, sections, dossiers) arrive en Phase 3 (docs/03_sidebar_navigation.md)
/// dans le module `SlateFeatures`.
struct SidebarPlaceholderView: View {
    var body: some View {
        ContentUnavailableView(
            String(localized: "sidebar.placeholder.title", defaultValue: "Barre latérale"),
            systemImage: "sidebar.left",
            description: Text(
                String(
                    localized: "sidebar.placeholder.description",
                    defaultValue: "Les espaces de travail et dossiers apparaîtront ici."
                )
            )
        )
        .padding(Spacing.md)
    }
}

#Preview {
    SidebarPlaceholderView()
}
