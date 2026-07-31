import SwiftUI

/// Etat global de selection courante de l'app (voir docs/GLOSSAIRE.md §5).
///
/// Phase 1 : uniquement des identifiants optionnels (`UUID?`), volontairement
/// decouples des types SwiftData (`Workspace`, `Folder`, `Note`) qui n'existent pas
/// encore (Phase 2, docs/02_modele_donnees.md). Les vues resoudront ces identifiants
/// en objets via des requetes `@Query` quand le vrai schema sera en place.
@Observable
@MainActor
public final class AppState {
    /// Identifiant du workspace actuellement selectionne (colonne sidebar).
    public var selectedWorkspaceID: UUID?

    /// Identifiant du dossier actuellement selectionne (colonne sidebar).
    public var selectedFolderID: UUID?

    /// Identifiant de la note actuellement selectionnee (colonne liste).
    public var selectedNoteID: UUID?

    public init(
        selectedWorkspaceID: UUID? = nil,
        selectedFolderID: UUID? = nil,
        selectedNoteID: UUID? = nil
    ) {
        self.selectedWorkspaceID = selectedWorkspaceID
        self.selectedFolderID = selectedFolderID
        self.selectedNoteID = selectedNoteID
    }
}

/// Injection de `AppState` dans l'environnement SwiftUI.
///
/// La conformance a `EnvironmentKey` est isolee au `MainActor` (syntaxe
/// `@MainActor EnvironmentKey`) car `AppState` lui-meme est `@MainActor`.
@MainActor
private struct AppStateKey: @MainActor EnvironmentKey {
    /// Valeur par defaut neutre : aucune selection. Toujours ecrasee par
    /// `SlateApp` via `.environment(\.appState, ...)`.
    static let defaultValue = AppState()
}

extension EnvironmentValues {
    /// Acces a l'`AppState` global depuis n'importe quelle vue :
    /// `@Environment(\.appState) private var appState`.
    ///
    /// Isole au `MainActor` comme `AppStateKey` : sans consequence pratique, les
    /// vues SwiftUI qui lisent `\.appState` s'executent deja sur le `MainActor`.
    @MainActor
    public var appState: AppState {
        get { self[AppStateKey.self] }
        set { self[AppStateKey.self] = newValue }
    }
}
