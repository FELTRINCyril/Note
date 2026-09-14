import Foundation
import Testing
import SlateModel
import SlateServices
@testable import SlateFeatures

/// Test d'integration de bout en bout de la dette de securite corrigee fin de jalon v1
/// (voir STATUT.md phase 12 et la documentation de tete de `Note`) : verrouiller,
/// deverrouiller EN SESSION (authentification reelle via `LockService`), consulter le
/// contenu, fermer la note - elle doit redevenir masquee, et rien de tout ce cycle ne
/// doit jamais avoir ecrit `isLocked = false` en base.
///
/// Reproduit cote logique ce que fait `NoteDetailColumnView` (choix entre
/// `LockedNoteView`/`NoteDocumentView` via `AppState.isUnlockedThisSession(_:)`,
/// deverrouillage via `LockService.verifyPassword(_:)` +
/// `AppState.markNoteRecentlyUnlocked(_:)`, fermeture via
/// `AutoRelockCoordinator.noteDidLoseFocus`), sans construire de vue SwiftUI.
/// Double `SecretStore` local (memoire), pour ne jamais toucher au Keychain reel de la
/// machine qui execute les tests. Distinct du double du meme nom dans
/// `SlateServicesTests` (cible de tests separee, non exportee).
private final class InMemorySecretStore: SecretStore, @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [String: Data] = [:]

    func read(key: String) -> Data? {
        lock.lock()
        defer { lock.unlock() }
        return storage[key]
    }

    @discardableResult
    func write(key: String, value: Data) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        storage[key] = value
        return true
    }

    @discardableResult
    func delete(key: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        storage.removeValue(forKey: key)
        return true
    }
}

@MainActor
struct LockSessionCycleTests {
    @Test("Cycle complet : verrouiller, deverrouiller en session, consulter, fermer, re-masquer")
    func fullLockUnlockCloseCycleReMasksTheNote() throws {
        let lockService = LockService(secretStore: InMemorySecretStore())
        try lockService.setPassword("CorrectHorse!42")
        let appState = AppState()

        let note = Note(title: "Comptes bancaires")
        note.blocks = [Block(order: 0, type: .paragraph, text: RichText(plainText: "IBAN secret"), note: note)]
        note.refreshDerivedText()

        // 1. Verrouiller.
        lockService.lock(note)
        #expect(note.isLocked)
        #expect(note.plainText.isEmpty)
        #expect(!appState.isUnlockedThisSession(note))

        // 2. Deverrouiller EN SESSION (mot de passe correct).
        #expect(lockService.verifyPassword("CorrectHorse!42"))
        appState.markNoteRecentlyUnlocked(note)

        // Toujours verrouillee en base : c'est le coeur de l'invariant de ce
        // changement, verifie ici via un deverrouillage reel (pas seulement construit
        // a la main comme dans `NoteLockingTests`).
        #expect(note.isLocked)
        #expect(note.plainText.isEmpty)
        #expect(note.snippetText.isEmpty)

        // 3. Consulter le contenu : c'est desormais permis puisque la session l'autorise.
        #expect(appState.isUnlockedThisSession(note))
        #expect(note.computedPlainText == "IBAN secret")

        // 4. Fermer la note (changement de selection / colonne detail qui disparait).
        AutoRelockCoordinator.noteDidLoseFocus(note, appState: appState)

        // 5. De nouveau masquee : ni visible en session, ni exposee par les champs
        // derives - exactement l'etat qu'un arret brutal aurait laisse INTACT, sans
        // dependre du bon deroulement de cette fermeture.
        #expect(!appState.isUnlockedThisSession(note))
        #expect(note.isLocked)
        #expect(note.plainText.isEmpty)
        #expect(note.snippetText.isEmpty)
    }

    /// Variante "arret brutal" : rien ne differencie l'etat juste apres le
    /// deverrouillage de session de l'etat juste apres un arret du processus, puisque
    /// aucune ecriture n'a jamais eu lieu pour le deverrouillage lui-meme. On simule
    /// l'arret brutal en construisant simplement un nouvel `AppState` (equivalent d'un
    /// nouveau lancement de process) sans passer par un quelconque reveerrouillage
    /// explicite.
    @Test("Un arret brutal (nouveau processus) ne laisse jamais de note deverrouillee")
    func simulatedCrashNeverLeavesANoteUnlocked() throws {
        let lockService = LockService(secretStore: InMemorySecretStore())
        try lockService.setPassword("CorrectHorse!42")
        let appState = AppState()

        let note = Note(title: "Comptes bancaires")
        note.blocks = [Block(order: 0, type: .paragraph, text: RichText(plainText: "IBAN secret"), note: note)]
        note.refreshDerivedText()

        lockService.lock(note)
        #expect(lockService.verifyPassword("CorrectHorse!42"))
        appState.markNoteRecentlyUnlocked(note)
        #expect(appState.isUnlockedThisSession(note))

        // "Arret brutal" : un processus frais ne connait par construction aucun etat
        // de session anterieur - `recentlyUnlockedNotes` n'est jamais persiste, il n'y
        // a donc rien a perdre ni a re-verrouiller au redemarrage.
        let freshProcessAppState = AppState()

        #expect(!freshProcessAppState.isUnlockedThisSession(note))
        #expect(note.isLocked)
        #expect(note.plainText.isEmpty)
        #expect(note.snippetText.isEmpty)
    }
}
