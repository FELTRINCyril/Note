import SwiftUI
import SlateModel

/// Etat global de selection courante de l'app (voir docs/GLOSSAIRE.md §5).
///
/// ## Choix de forme : references de modele plutot que `UUID?`
///
/// Jusqu'a la Phase 3, `AppState` portait des `UUID?` decouples de tout type SwiftData,
/// parce que ces types n'existaient pas encore (Phase 2). Maintenant que `SlateModel`
/// est livre, cette phase tranche pour des references directes aux objets
/// (`Workspace?`, `Folder?`, `Note?`) plutot que de continuer avec des identifiants.
///
/// Justification :
/// - `AppState` est deja `@MainActor`, et tous les objets `@Model` de cette app ne
///   vivent que sur le `MainActor` (aucun acteur de fond ne les touche en Phase 3) :
///   garder une reference directe ne viole donc aucune regle de concurrence Swift 6,
///   meme si `Folder`/`Note`/`Workspace` ne sont pas eux-memes `Sendable`.
/// - La cascade de selection (§critere d'acceptation : "Selectionner un dossier change
///   bien la colonne du milieu") a besoin d'acceder directement aux proprietes du
///   dossier selectionne (`folder.name`, `folder.noteCount`, `folder.subfolders`...).
///   Avec un `UUID?`, chaque vue consommatrice devrait re-executer une requete
///   (`FetchDescriptor` ou parcours de `@Query`) juste pour retrouver l'objet a partir
///   de l'identifiant, a chaque acces. Avec une reference directe, c'est immediat et
///   l'observation SwiftUI (`@Observable` + acces aux proprietes du `@Model`) suit les
///   mutations sans code supplementaire.
/// - La contrepartie assumee : une reference peut devenir "pendante" si l'objet
///   selectionne est supprime pendant que la reference est encore active (ex :
///   suppression d'un dossier selectionne depuis un menu contextuel). C'est un risque
///   *equivalent*, pas pire, qu'un `UUID?` : un identifiant orphelin apres suppression
///   pose exactement le meme probleme (une requete par id ne retrouve plus rien). Les
///   vues qui suppriment un dossier/une note doivent donc explicitement nettoyer
///   `AppState` quand l'objet supprime est celui actuellement selectionne (voir
///   `FolderRow` : suppression d'un dossier reinitialise `selectedFolder` si necessaire).
@Observable
@MainActor
public final class AppState {
    /// Workspace actuellement selectionne (selecteur de la sidebar). Reellement
    /// multi-valeurs a partir de la Phase 19 ; en Phase 3, un seul workspace existe
    /// (cree par `WorkspaceBootstrap` au premier lancement).
    public var selectedWorkspace: Workspace?

    /// Dossier actuellement selectionne dans la sidebar. Alimente la colonne du milieu
    /// (Phase 4 pour le vrai contenu ; en Phase 3, le placeholder affiche son nom et
    /// son nombre de notes pour prouver la cascade de selection).
    public var selectedFolder: Folder?

    /// Note actuellement selectionnee dans la colonne liste. Alimente la colonne
    /// detail (Phase 5).
    public var selectedNote: Note?

    public init(
        selectedWorkspace: Workspace? = nil,
        selectedFolder: Folder? = nil,
        selectedNote: Note? = nil
    ) {
        self.selectedWorkspace = selectedWorkspace
        self.selectedFolder = selectedFolder
        self.selectedNote = selectedNote
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
