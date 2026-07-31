import Testing
import SwiftUI
@testable import SlateFeatures

/// Tests de la logique pure de bascule des colonnes (Phase 3, spec E1 "collapse - 3
/// etats de colonnes"). Pas de rendu SwiftUI ici : uniquement l'etat et sa derivation
/// vers `NavigationSplitViewVisibility`.
@Suite("ColumnLayoutState")
struct ColumnLayoutStateTests {

    @Test("Etat par defaut : tout est visible")
    func defaultStateShowsEverything() {
        let state = ColumnLayoutState.all
        #expect(state.nativeVisibility == .all)
        #expect(!state.isListColumnCollapsed)
        #expect(!state.isFocusMode)
    }

    @Test("Cmd+1 masque puis restaure la sidebar")
    func toggleSidebarTwiceRestoresDefault() {
        var state = ColumnLayoutState.all
        state.toggleSidebar()
        #expect(state.nativeVisibility == .doubleColumn)
        state.toggleSidebar()
        #expect(state.nativeVisibility == .all)
    }

    @Test("Cmd+2 masque la liste sans toucher la sidebar")
    func toggleListDoesNotAffectSidebar() {
        var state = ColumnLayoutState.all
        state.toggleList()
        #expect(state.nativeVisibility == .all)
        #expect(state.isListColumnCollapsed)
        #expect(state.isSidebarVisible)
    }

    @Test("Mode focus masque sidebar et liste via .detailOnly")
    func focusModeUsesDetailOnly() {
        var state = ColumnLayoutState.all
        state.toggleFocusMode()
        #expect(state.nativeVisibility == .detailOnly)
        #expect(state.isFocusMode)
    }

    @Test("Sortir du mode focus restaure l'etat precedent")
    func exitingFocusModeRestoresPreviousState() {
        var state = ColumnLayoutState.all
        state.toggleSidebar()
        state.toggleList()
        // Sidebar masquee, liste masquee, avant l'entree en mode focus.
        state.toggleFocusMode()
        #expect(state.nativeVisibility == .detailOnly)
        state.toggleFocusMode()
        #expect(state.nativeVisibility == .doubleColumn)
        #expect(state.isListColumnCollapsed)
    }

    @Test("Basculer la sidebar en mode focus en sort plutot que de rouvrir la sidebar")
    func togglingSidebarWhileInFocusModeExitsFocusMode() {
        var state = ColumnLayoutState.all
        state.toggleFocusMode()
        #expect(state.isFocusMode)
        state.toggleSidebar()
        #expect(!state.isFocusMode)
        #expect(state.nativeVisibility == .all)
    }
}
