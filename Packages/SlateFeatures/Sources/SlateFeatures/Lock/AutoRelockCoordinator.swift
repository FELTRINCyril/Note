import Foundation
import SlateModel
import SlateServices

/// Cablage du reverrouillage automatique (`docs/12_verrouillage.md`) : `LockService`
/// livre les primitives d'authentification, mais AUCUN appelant -- c'est le morceau
/// manquant que cette phase doit cabler.
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
///
/// ## Ce type ne mute plus jamais `Note.isLocked` (dette de securite corrigee)
///
/// `Note.isLocked` reste vrai en permanence une fois une note verrouillee (voir la
/// documentation de tete de `Note` et `AppState.recentlyUnlockedNotes`) : une note
/// presente dans ce registre est donc DEJA verrouillee en base, et "la reverrouiller"
/// ne consiste plus qu'a la retirer du registre de session, sans plus aucune ecriture
/// dans le store. C'est ce qui ferme le trou de securite : il n'y a plus rien a
/// persister au moment du reverrouillage, donc plus rien qu'un arret brutal puisse
/// laisser en suspens.
@MainActor
enum AutoRelockCoordinator {
    /// A appeler quand `previousNote` cesse d'etre affichee (changement de selection,
    /// fermeture de la colonne detail). "Reverrouille" `previousNote` UNIQUEMENT si
    /// elle a ete deverrouillee cette session (voir `AppState.recentlyUnlockedNotes`)
    /// -- une note qui n'a jamais ete protegee ne doit jamais etre affectee par ce
    /// chemin.
    static func noteDidLoseFocus(_ previousNote: Note?, appState: AppState) {
        guard let previousNote, appState.isUnlockedThisSession(previousNote) else { return }
        appState.removeRecentlyUnlockedNote(previousNote)
    }

    /// "Reverrouille" TOUTES les notes deverrouillees cette session (verrouillage de
    /// l'app/de l'ecran macOS : aucune raison de n'en epargner qu'une seule) en vidant
    /// simplement le registre de session.
    static func relockAllUnlockedNotes(appState: AppState) {
        appState.recentlyUnlockedNotes.removeAll()
    }

    /// Verifie l'inactivite systeme (`idleSeconds`, voir `SystemIdleTime`) contre
    /// `autoRelock` et "reverrouille" toutes les notes deverrouillees si le seuil est
    /// depasse. No-op si aucune note n'est actuellement deverrouillee (evite tout
    /// calcul/effet quand il n'y a rien a proteger).
    static func relockIfInactive(
        autoRelock: InactivityAutoRelock,
        idleSeconds: TimeInterval,
        appState: AppState,
        now: Date = .now
    ) {
        guard !appState.recentlyUnlockedNotes.isEmpty else { return }
        let lastActivityAt = now.addingTimeInterval(-idleSeconds)
        guard autoRelock.shouldRelock(lastActivityAt: lastActivityAt, now: now) else { return }
        relockAllUnlockedNotes(appState: appState)
    }
}
