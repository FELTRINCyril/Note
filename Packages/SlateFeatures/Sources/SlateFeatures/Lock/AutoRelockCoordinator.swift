import Foundation
import SlateModel
import SlateServices

/// Cablage du reverrouillage automatique (`docs/12_verrouillage.md`) : `LockService`
/// livre les primitives (`lock(_:)`, `InactivityAutoRelock.shouldRelock`), mais AUCUN
/// appelant -- c'est le morceau manquant que cette phase doit cabler.
///
/// Fonctions statiques, sans etat propre (tout l'etat mutable vit sur `AppState`,
/// injecte en parametre) : testables sans construire de vue SwiftUI ni de
/// `ModelContext`, meme motif que `NoteListView.partitionByPinned`.
///
/// Trois points d'appel attendus (voir leurs sites d'appel) :
/// - `noteDidLoseFocus` : quand `appState.selectedNote` change ou que la colonne
///   detail disparait (fermeture de la note).
/// - `relockIfInactive` : verifie periodiquement contre `SystemIdleTime`.
/// - `relockAllUnlockedNotes` : au verrouillage de l'ecran macOS (`MainWindowView`,
///   notification distribuee `com.apple.screenIsLocked`).
@MainActor
enum AutoRelockCoordinator {
    /// A appeler quand `previousNote` cesse d'etre affichee (changement de selection,
    /// fermeture de la colonne detail). Reverrouille `previousNote` UNIQUEMENT si elle
    /// a ete deverrouillee cette session (voir `AppState.recentlyUnlockedNotes`) --
    /// une note qui n'a jamais ete protegee ne doit jamais se faire verrouiller par ce
    /// chemin.
    static func noteDidLoseFocus(_ previousNote: Note?, appState: AppState, lockService: LockService) {
        guard let previousNote,
            appState.recentlyUnlockedNotes.contains(where: { $0.id == previousNote.id })
        else { return }
        lockService.lock(previousNote)
        appState.removeRecentlyUnlockedNote(previousNote)
    }

    /// Reverrouille TOUTES les notes deverrouillees cette session (verrouillage de
    /// l'app/de l'ecran macOS : aucune raison de n'en epargner qu'une seule).
    static func relockAllUnlockedNotes(appState: AppState, lockService: LockService) {
        for note in appState.recentlyUnlockedNotes {
            lockService.lock(note)
        }
        appState.recentlyUnlockedNotes.removeAll()
    }

    /// Verifie l'inactivite systeme (`idleSeconds`, voir `SystemIdleTime`) contre
    /// `autoRelock` et reverrouille toutes les notes deverrouillees si le seuil est
    /// depasse. No-op si aucune note n'est actuellement deverrouillee (evite tout
    /// calcul/effet quand il n'y a rien a proteger).
    static func relockIfInactive(
        autoRelock: InactivityAutoRelock,
        idleSeconds: TimeInterval,
        appState: AppState,
        lockService: LockService,
        now: Date = .now
    ) {
        guard !appState.recentlyUnlockedNotes.isEmpty else { return }
        let lastActivityAt = now.addingTimeInterval(-idleSeconds)
        guard autoRelock.shouldRelock(lastActivityAt: lastActivityAt, now: now) else { return }
        relockAllUnlockedNotes(appState: appState, lockService: lockService)
    }
}
