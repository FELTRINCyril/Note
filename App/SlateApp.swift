import SwiftUI
import SwiftData
import SlateModel

/// Point d'entree de l'application Slate (macOS).
///
/// Phase 1 : fenetre unique contenant `RootView` (3 colonnes vides), container
/// SwiftData injecte via `SlateContainer.make()` (docs/01_setup_projet.md, etape 1.3).
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
                RootView()
                    .environment(\.appState, appState)
                    .modelContainer(container)
            case .failure(let error):
                ContainerErrorView(error: error)
            }
        }
    }
}
