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
                .slateColumnWidth(NavigationLayout.sidebarWidth)
        } content: {
            NoteListPlaceholderView()
                .slateColumnWidth(NavigationLayout.listWidth)
        } detail: {
            NoteDetailPlaceholderView()
        }
    }
}

#Preview {
    RootView()
}
