import Foundation

/// Panneau vise par un deplacement de focus clavier (Phase 14, `docs/RACCOURCIS.md` :
/// ⌃⌘1/⌃⌘2/⌃⌘3). Porte par un `@FocusState` UNIQUE au niveau de `MainWindowView` (voir
/// sa documentation) et PROJETE vers `SidebarView`/`NoteListView` via leur parametre
/// `panelFocus` (`FocusState<SlatePanelFocus?>.Binding`, le mecanisme standard SwiftUI
/// pour qu'un parent commande le focus d'un enfant sans en posseder l'etat interne --
/// voir la documentation de `MainWindowView.focusedPanel`).
///
/// L'editeur n'a volontairement PAS de cas ici : `NoteDocumentView` deplace la
/// selection de bloc via `EditorController.selectBlock(_:)`, un mecanisme distinct et
/// deja existant expose par `EditorFocusedValues.swift` (`SlateEditor`) -- dupliquer ce
/// deplacement avec ce `@FocusState` SwiftUI generique risquerait d'interferer avec le
/// focus AppKit interne, delicat, de l'editeur (voir `docs/RACCOURCIS.md`).
public enum SlatePanelFocus: Hashable {
    case sidebar
    case list
}
