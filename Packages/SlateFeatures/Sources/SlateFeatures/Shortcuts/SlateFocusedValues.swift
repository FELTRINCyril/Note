import SwiftUI

/// Valeurs publiees par les vues actuellement affichees pour piloter les commandes de
/// la barre de menu (`SlateAppCommands.swift`), sans que celles-ci aient besoin d'un
/// acces direct a `AppState`/`ModelContext`/`ModelContainer` (que `App.body` ne peut de
/// toute facon pas leur fournir avant que le container ait ete cree avec succes, voir
/// `SlateApp.containerResult`).
///
/// C'est le mecanisme standard SwiftUI pour relier les commandes d'une `Scene` a
/// l'etat de la vue courante : chaque vue publie sa propre action via
/// `.focusedSceneValue(_:_:)`, et `SlateAppCommands` la lit via `@FocusedValue`. Une
/// action non publiee (aucune fenetre au premier plan, aucune note selectionnee...)
/// vaut `nil`, et l'entree de menu correspondante se desactive -- jamais un no-op
/// silencieux (regle d'honnetete d'interface du projet).
@MainActor
private struct NewNoteActionKey: FocusedValueKey {
    typealias Value = () -> Void
}

@MainActor
private struct NewFolderActionKey: FocusedValueKey {
    typealias Value = () -> Void
}

@MainActor
private struct NoteMenuActionsKey: FocusedValueKey {
    typealias Value = NoteMenuCommandActions
}

@MainActor
private struct ToggleSidebarActionKey: FocusedValueKey {
    typealias Value = () -> Void
}

@MainActor
private struct ToggleListActionKey: FocusedValueKey {
    typealias Value = () -> Void
}

@MainActor
private struct ToggleFocusModeActionKey: FocusedValueKey {
    typealias Value = () -> Void
}

@MainActor
private struct FocusSidebarActionKey: FocusedValueKey {
    typealias Value = () -> Void
}

@MainActor
private struct FocusListActionKey: FocusedValueKey {
    typealias Value = () -> Void
}

/// Isole au `MainActor` comme les cles ci-dessus (meme motif que `AppState.swift`).
@MainActor
extension FocusedValues {
    /// Cree une nouvelle note dans le dossier selectionne (publie par `SidebarView`).
    /// `nil` si aucun dossier n'est selectionne (meme garde que `SidebarFooterView.canCreateNote`).
    public var newNoteAction: (() -> Void)? {
        get { self[NewNoteActionKey.self] }
        set { self[NewNoteActionKey.self] = newValue }
    }

    /// Cree un nouveau dossier (publie par `SidebarView`). Toujours disponible des
    /// qu'un workspace existe, meme garde que `SidebarFooterView`.
    public var newFolderAction: (() -> Void)? {
        get { self[NewFolderActionKey.self] }
        set { self[NewFolderActionKey.self] = newValue }
    }

    /// Actions sur la note/la selection courante (publie par `NoteListView`). `nil` si
    /// aucune note n'est selectionnee.
    public var noteMenuActions: NoteMenuCommandActions? {
        get { self[NoteMenuActionsKey.self] }
        set { self[NoteMenuActionsKey.self] = newValue }
    }

    /// Bascule la visibilite de la barre laterale (publie par `MainWindowView`).
    public var toggleSidebarAction: (() -> Void)? {
        get { self[ToggleSidebarActionKey.self] }
        set { self[ToggleSidebarActionKey.self] = newValue }
    }

    /// Bascule la visibilite de la colonne liste (publie par `MainWindowView`).
    public var toggleListAction: (() -> Void)? {
        get { self[ToggleListActionKey.self] }
        set { self[ToggleListActionKey.self] = newValue }
    }

    /// Bascule le mode focus (publie par `MainWindowView`).
    public var toggleFocusModeAction: (() -> Void)? {
        get { self[ToggleFocusModeActionKey.self] }
        set { self[ToggleFocusModeActionKey.self] = newValue }
    }

    /// Deplace le focus clavier vers la barre laterale (publie par `MainWindowView`,
    /// Phase 14, ⌃⌘1) -- voir `SlatePanelFocus`.
    public var focusSidebarAction: (() -> Void)? {
        get { self[FocusSidebarActionKey.self] }
        set { self[FocusSidebarActionKey.self] = newValue }
    }

    /// Deplace le focus clavier vers la colonne liste (publie par `MainWindowView`,
    /// Phase 14, ⌃⌘2) -- voir `SlatePanelFocus`.
    public var focusListAction: (() -> Void)? {
        get { self[FocusListActionKey.self] }
        set { self[FocusListActionKey.self] = newValue }
    }
}
