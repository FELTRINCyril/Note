import Foundation
import Testing
import SlateModel
import SlateServices
@testable import SlateFeatures

/// Cablage du reverrouillage automatique (Phase 12, `docs/12_verrouillage.md`,
/// revu en dette de securite fin de jalon v1) : `AutoRelockCoordinator` est le seul
/// endroit qui decide QUAND "reverrouiller", c'est-a-dire retirer une note du registre
/// de session `AppState.recentlyUnlockedNotes` - il ne mute plus jamais
/// `Note.isLocked`, qui reste vrai en permanence des qu'une note a ete verrouillee au
/// moins une fois (voir `Note.lock()`).
///
/// Chaque fixture appelle donc explicitement `note.lock()` avant de simuler un
/// deverrouillage de session (`markNoteRecentlyUnlocked`), pour rester fidele a
/// l'invariant reel : une note ne peut entrer dans ce registre qu'apres avoir ete
/// verrouillee (voir `NoteDetailColumnView`, seul site d'appel de
/// `markNoteRecentlyUnlocked`).
@MainActor
@Suite("AutoRelockCoordinator")
struct AutoRelockCoordinatorTests {
    @Test("noteDidLoseFocus retire du registre de session une note deverrouillee cette session")
    func noteDidLoseFocusRelocksTrackedNote() {
        let note = Note(title: "Comptes bancaires")
        note.lock()
        let appState = AppState()
        appState.markNoteRecentlyUnlocked(note)

        AutoRelockCoordinator.noteDidLoseFocus(note, appState: appState)

        #expect(note.isLocked)
        #expect(appState.recentlyUnlockedNotes.isEmpty)
    }

    @Test("noteDidLoseFocus n'affecte jamais une note qui n'a jamais ete deverrouillee cette session")
    func noteDidLoseFocusIgnoresUntrackedNote() {
        let note = Note(title: "Note ordinaire")
        let appState = AppState()

        AutoRelockCoordinator.noteDidLoseFocus(note, appState: appState)

        #expect(!note.isLocked)
    }

    @Test("noteDidLoseFocus avec nil ne fait rien")
    func noteDidLoseFocusIgnoresNil() {
        let appState = AppState()
        AutoRelockCoordinator.noteDidLoseFocus(nil, appState: appState)
        #expect(appState.recentlyUnlockedNotes.isEmpty)
    }

    @Test("relockAllUnlockedNotes vide le registre de session pour toutes les notes suivies")
    func relockAllUnlockedNotes() {
        let noteA = Note(title: "A")
        noteA.lock()
        let noteB = Note(title: "B")
        noteB.lock()
        let appState = AppState()
        appState.markNoteRecentlyUnlocked(noteA)
        appState.markNoteRecentlyUnlocked(noteB)

        AutoRelockCoordinator.relockAllUnlockedNotes(appState: appState)

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
            appState: appState
        )
        #expect(appState.recentlyUnlockedNotes.isEmpty)
    }

    @Test("relockIfInactive vide le registre de session au-dela du seuil d'inactivite")
    func relockIfInactiveBeyondThreshold() {
        let note = Note(title: "Comptes bancaires")
        note.lock()
        let appState = AppState()
        appState.markNoteRecentlyUnlocked(note)

        AutoRelockCoordinator.relockIfInactive(
            autoRelock: InactivityAutoRelock(threshold: 300),
            idleSeconds: 301,
            appState: appState
        )

        #expect(note.isLocked)
        #expect(appState.recentlyUnlockedNotes.isEmpty)
    }

    @Test("relockIfInactive ne vide pas le registre en-deca du seuil d'inactivite")
    func relockIfInactiveBelowThreshold() {
        let note = Note(title: "Comptes bancaires")
        note.lock()
        let appState = AppState()
        appState.markNoteRecentlyUnlocked(note)

        AutoRelockCoordinator.relockIfInactive(
            autoRelock: InactivityAutoRelock(threshold: 300),
            idleSeconds: 299,
            appState: appState
        )

        #expect(note.isLocked)
        #expect(!appState.recentlyUnlockedNotes.isEmpty)
    }
}
