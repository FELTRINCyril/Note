import SwiftUI
import SlateUI

/// Racine de navigation de l'app : `NavigationSplitView` a 3 colonnes
/// (sidebar | liste | detail), voir docs/00_architecture.md §Patterns.
///
/// Phase 1 : les 3 colonnes sont des placeholders vides. Elles migreront vers
/// `SlateFeatures` a partir de la Phase 3 (docs/01_setup_projet.md, etape 1.5).
struct RootView: View {
    @State private var columnVisibility: NavigationSplitViewVisibility = .automatic

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarPlaceholderView()
                .navigationSplitViewColumnWidth(
                    min: NavigationLayout.sidebarWidth.min,
                    ideal: NavigationLayout.sidebarWidth.ideal,
                    max: NavigationLayout.sidebarWidth.max
                )
        } content: {
            NoteListPlaceholderView()
                .navigationSplitViewColumnWidth(
                    min: NavigationLayout.listWidth.min,
                    ideal: NavigationLayout.listWidth.ideal,
                    max: NavigationLayout.listWidth.max
                )
        } detail: {
            NoteDetailPlaceholderView()
        }
    }
}

#Preview {
    RootView()
}
