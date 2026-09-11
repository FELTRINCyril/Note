import Foundation
import Testing
import SlateModel
import SlateServices
@testable import SlateFeatures

/// Cablage du reverrouillage automatique (Phase 12, `docs/12_verrouillage.md`) :
/// `AutoRelockCoordinator` est le seul endroit qui decide QUAND reverrouiller, a
/// partir des primitives deja livrees par `SlateServices` (`LockService.lock(_:)`,
/// `InactivityAutoRelock.shouldRelock`).
///
/// `LockService()` par defaut (Keychain reel) est utilisable ici SANS toucher au
/// Keychain : seul `lock(_:)` est exerce, qui ne fait que muter l'objet `Note` en
/// memoire (voir sa documentation) -- aucune des methodes qui lisent/ecrivent le
/// Keychain (`setPassword`/`verifyPassword`/`isPasswordSet`) n'est appelee par ces
/// tests.
@MainActor
@Suite("AutoRelockCoordinator")
struct AutoRelockCoordinatorTests {
    private let lockService = LockService()

    @Test("noteDidLoseFocus reverrouille une note deverrouillee cette session")
    func noteDidLoseFocusRelocksTrackedNote() {
        let note = Note(title: "Comptes bancaires")
        let appState = AppState()
        appState.markNoteRecentlyUnlocked(note)

        AutoRelockCoordinator.noteDidLoseFocus(note, appState: appState, lockService: lockService)

        #expect(note.isLocked)
        #expect(appState.recentlyUnlockedNotes.isEmpty)
    }

    @Test("noteDidLoseFocus n'affecte jamais une note qui n'a jamais ete deverrouillee cette session")
    func noteDidLoseFocusIgnoresUntrackedNote() {
        let note = Note(title: "Note ordinaire")
        let appState = AppState()

        AutoRelockCoordinator.noteDidLoseFocus(note, appState: appState, lockService: lockService)

        #expect(!note.isLocked)
    }

    @Test("noteDidLoseFocus avec nil ne fait rien")
    func noteDidLoseFocusIgnoresNil() {
        let appState = AppState()
        AutoRelockCoordinator.noteDidLoseFocus(nil, appState: appState, lockService: lockService)
        #expect(appState.recentlyUnlockedNotes.isEmpty)
    }

    @Test("relockAllUnlockedNotes reverrouille toutes les notes suivies et vide le registre")
    func relockAllUnlockedNotes() {
        let noteA = Note(title: "A")
        let noteB = Note(title: "B")
        let appState = AppState()
        appState.markNoteRecentlyUnlocked(noteA)
        appState.markNoteRecentlyUnlocked(noteB)

        AutoRelockCoordinator.relockAllUnlockedNotes(appState: appState, lockService: lockService)

        #expect(noteA.isLocked)
        #expect(noteB.isLocked)
        #expect(appState.recentlyUnlockedNotes.isEmpty)
    }

    @Test("relockIfInactive ne fait rien tant qu'aucune note n'est deverrouillee")
    func relockIfInactiveNoOpWithoutUnlockedNotes() {
        let appState = AppState()
        AutoRelockCoordinator.relockIfInactive(
            autoRelock: InactivityAutoRelock(threshold: 300),
            idleSeconds: 10_000,
            appState: appState,
            lockService: lockService
        )
        #expect(appState.recentlyUnlockedNotes.isEmpty)
    }

    @Test("relockIfInactive reverrouille au-dela du seuil d'inactivite")
    func relockIfInactiveBeyondThreshold() {
        let note = Note(title: "Comptes bancaires")
        let appState = AppState()
        appState.markNoteRecentlyUnlocked(note)

        AutoRelockCoordinator.relockIfInactive(
            autoRelock: InactivityAutoRelock(threshold: 300),
            idleSeconds: 301,
            appState: appState,
            lockService: lockService
        )

        #expect(note.isLocked)
        #expect(appState.recentlyUnlockedNotes.isEmpty)
    }

    @Test("relockIfInactive ne reverrouille pas en-deca du seuil d'inactivite")
    func relockIfInactiveBelowThreshold() {
        let note = Note(title: "Comptes bancaires")
        let appState = AppState()
        appState.markNoteRecentlyUnlocked(note)

        AutoRelockCoordinator.relockIfInactive(
            autoRelock: InactivityAutoRelock(threshold: 300),
            idleSeconds: 299,
            appState: appState,
            lockService: lockService
        )

        #expect(!note.isLocked)
        #expect(!appState.recentlyUnlockedNotes.isEmpty)
    }
}
