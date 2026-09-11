import Testing
import SlateModel
@testable import SlateFeatures

/// Regle de desactivation de "Verrouiller la note" (Phase 12, `docs/12_verrouillage.md`) :
/// jamais de deverrouillage via ce menu (voir la documentation de tete de
/// `NoteContextMenuContent`), donc desactive des qu'au moins une note de la selection
/// est deja verrouillee.
@MainActor
@Suite("NoteContextMenuContent.isLockDisabled")
struct NoteContextMenuContentTests {
    @Test("Selection vide : desactive")
    func emptySelectionIsDisabled() {
        #expect(NoteContextMenuContent.isLockDisabled(for: []))
    }

    @Test("Selection sans note verrouillee : actif")
    func selectionWithoutLockedNoteIsEnabled() {
        let notes = [Note(title: "A"), Note(title: "B")]
        #expect(!NoteContextMenuContent.isLockDisabled(for: notes))
    }

    @Test("Au moins une note verrouillee dans la selection : desactive")
    func selectionWithAtLeastOneLockedNoteIsDisabled() {
        let notes = [Note(title: "A"), Note(title: "B", isLocked: true)]
        #expect(NoteContextMenuContent.isLockDisabled(for: notes))
    }

    @Test("Une seule note deja verrouillee : desactive")
    func singleLockedNoteIsDisabled() {
        let notes = [Note(title: "A", isLocked: true)]
        #expect(NoteContextMenuContent.isLockDisabled(for: notes))
    }
}
