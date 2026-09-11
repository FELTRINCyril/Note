import SwiftUI
import SwiftData
import SlateModel
import SlateFeatures
import SlateServices

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

    /// Reverrouillage des notes ouvertes a l'extinction de l'app (phase 12).
    ///
    /// `SlateFeatures` couvre deja trois declencheurs de reverrouillage (fermeture de
    /// la note, inactivite, verrouillage de l'ecran macOS), mais la fermeture de l'app
    /// elle-meme ne peut etre observee que d'ici : un package ne voit pas le cycle de
    /// vie `NSApplication`. Sans ce quatrieme declencheur, deverrouiller une note puis
    /// quitter Slate la laisserait deverrouillee EN BASE - donc son contenu de nouveau
    /// visible dans l'extrait de la liste et trouvable par la recherche au prochain
    /// lancement. Voir `Note.refreshDerivedText()` pour l'invariant concerne.
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

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
                    .task { appDelegate.appState = appState }
            case .failure(let error):
                ContainerErrorView(error: error)
            }
        }
    }
}

/// Delegue d'application, reduit au strict necessaire : le reverrouillage des notes
/// a l'extinction.
///
/// PORTEE ASSUMEE : ce declencheur couvre une extinction NORMALE (Quitter, fermeture
/// de session). Il ne couvre PAS un arret brutal (plantage, `kill -9`, coupure de
/// courant), ou `applicationWillTerminate` n'est jamais appele - une note deverrouillee
/// resterait alors deverrouillee en base. La correction de fond serait de ne jamais
/// persister l'etat "deverrouille" (garder `isLocked` vrai en permanence et ne porter
/// le deverrouillage que dans l'etat de session, facon Notes d'Apple), ce qui est un
/// changement de modele a part entiere : voir STATUT.md, points ouverts de la phase 12.
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// Renseigne au montage de la vue racine : le delegue est construit par AppKit
    /// avant que l'etat de l'app n'existe, il ne peut donc pas le recevoir a l'init.
    var appState: AppState?

    private let lockService = LockService()

    @MainActor
    func applicationWillTerminate(_ notification: Notification) {
        guard let appState else { return }
        let notes = appState.recentlyUnlockedNotes
        // Le contexte est lu AVANT de vider le registre, sinon il n'y aurait plus
        // aucune note par laquelle l'atteindre.
        let context = notes.first?.modelContext
        for note in notes {
            lockService.lock(note)
        }
        appState.recentlyUnlockedNotes.removeAll()
        // Les notes reverrouillees viennent d'etre modifiees : sans ce `save`, la
        // fenetre d'autosave de SwiftData peut ne jamais s'ouvrir avant l'extinction,
        // et le reverrouillage serait perdu - exactement le trou qu'on ferme ici.
        try? context?.save()
    }
}
