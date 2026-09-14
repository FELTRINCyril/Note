import SwiftUI
import SwiftData
import SlateModel
import SlateFeatures
import SlateUI

/// Point d'entree de l'application Slate (macOS).
///
/// Coquille fine : instancie l'`AppState` global (desormais porte par
/// `SlateFeatures`, voir `docs/03_sidebar_navigation.md` - un package ne peut pas
/// voir le code de la cible app, la vue racine `MainWindowView` doit donc vivre dans
/// `SlateFeatures`), cree le container SwiftData, et affiche `MainWindowView`.
///
/// La creation du container peut echouer (disque plein, schema incompatible...) :
/// on ne masque jamais cette erreur avec `try!`, on affiche `ContainerErrorView` a la
/// place pour rester diagnosticable sans crash.
@main
struct SlateApp: App {
    @State private var appState = AppState()

    /// Resultat de la creation du container, calcule une seule fois au lancement.
    private let containerResult: Result<ModelContainer, any Error>

    init() {
        containerResult = Result { try SlateContainer.make() }
    }

    var body: some Scene {
        WindowGroup {
            // Phase 13 : `ThemeManager.shared.preferredColorScheme` pilote le theme
            // (Systeme/Clair/Sombre choisi dans les reglages) pour TOUTE la fenetre
            // principale -- `Group` regroupe les deux branches du `switch` pour
            // n'appliquer le modificateur qu'une fois. `nil` (theme "Systeme") laisse
            // macOS decider, comme documente sur `ThemeManager.preferredColorScheme`.
            Group {
                switch containerResult {
                case .success(let container):
                    MainWindowView()
                        .environment(\.appState, appState)
                        .environment(ThemeManager.shared)
                        .modelContainer(container)
                case .failure(let error):
                    ContainerErrorView(error: error)
                }
            }
            .preferredColorScheme(ThemeManager.shared.preferredColorScheme)
        }
        // Phase 14 : barre de menu macOS (Fichier/Edition/Format/Affichage) --
        // `SlateAppCommands` lit l'etat de la fenetre au premier plan via
        // `@FocusedValue` (voir `SlateFocusedValues.swift`), ce fichier n'a donc besoin
        // de rien lui transmettre explicitement.
        .commands { SlateAppCommands() }

        // Phase 13 : fenetre de reglages standard macOS (Menu Slate > Reglages,
        // Cmd+,). `SettingsWindowView` ne depend d'aucun `ModelContainer` explicite
        // (elle lit `SlateContainer.isCloudKitEnabled`, un fait de compilation, pas
        // le container lui-meme) : pas besoin de la brancher au `containerResult`.
        Settings {
            SettingsWindowView()
                .preferredColorScheme(ThemeManager.shared.preferredColorScheme)
        }
    }
}

// L'`AppDelegate` qui vivait ici (reverrouillage des notes a l'extinction normale de
// l'app, `applicationWillTerminate`) a ete SUPPRIME (dette de securite corrigee, voir
// STATUT.md phase 12) : il ne protegeait de toute facon QUE l'extinction normale
// (Quitter, fermeture de session), jamais un arret brutal (plantage, `kill -9`,
// coupure de courant), ou `applicationWillTerminate` n'est jamais appele - exactement
// le cas qui compte le plus en securite. Le vrai correctif est en amont, dans
// `SlateModel.Note` : `isLocked` ne repasse plus jamais a `false` en base, le
// deverrouillage n'etant plus qu'un etat de session (`AppState.
// recentlyUnlockedNotes`) qui disparait de lui-meme avec le processus, QUELLE QUE SOIT
// la maniere dont celui-ci se termine. Garder ce delegue alors qu'il ne fermait plus
// aucun trou reel aurait ete une fausse protection - pire qu'une absence de code, car
// elle aurait laisse croire que le cas grave (arret brutal) restait couvert.
