import SwiftUI
import SwiftData
import SlateModel
import SlateFeatures

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
            switch containerResult {
            case .success(let container):
                MainWindowView()
                    .environment(\.appState, appState)
                    .modelContainer(container)
            case .failure(let error):
                ContainerErrorView(error: error)
            }
        }
    }
}
