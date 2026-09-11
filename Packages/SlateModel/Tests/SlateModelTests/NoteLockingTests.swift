import Foundation
import SwiftData
import Testing

@testable import SlateModel

/// Verifie l'invariant de securite de la Phase 12 (voir la documentation de `Note`,
/// section "Verrouillage") : une note verrouillee n'expose jamais `plainText`/
/// `snippetText` en clair, quel que soit le chemin par lequel on arrive a
/// `isLocked == true`, et les recupere correctement au deverrouillage.
@MainActor
struct NoteLockingTests {

    private func noteWithContent(title: String = "Confidentiel") -> Note {
        let note = Note(title: title)
        note.blocks = [Block(order: 0, type: .paragraph, text: RichText(plainText: "Secret."), note: note)]
        note.refreshDerivedText()
        return note
    }

    @Test
    func lockClearsPlainTextAndSnippetButKeepsTitle() {
        let note = noteWithContent()
        #expect(note.plainText == "Secret.")

        note.lock()

        #expect(note.isLocked)
        #expect(note.plainText.isEmpty)
        #expect(note.snippetText.isEmpty)
        #expect(note.title == "Confidentiel")
    }

    @Test
    func unlockRebuildsPlainTextAndSnippetFromBlocks() {
        let note = noteWithContent()
        note.lock()
        #expect(note.plainText.isEmpty)

        note.unlock()

        #expect(!note.isLocked)
        #expect(note.plainText == "Secret.")
        #expect(note.snippetText == "Secret.")
    }

    @Test
    func lockUnlockRelockCycleLeavesDerivedTextConsistent() {
        let note = noteWithContent()

        note.lock()
        #expect(note.plainText.isEmpty)

        note.unlock()
        #expect(note.plainText == "Secret.")

        note.lock()
        #expect(note.plainText.isEmpty)
        #expect(note.snippetText.isEmpty)
    }

    /// L'invariant est porte par `refreshDerivedText()` lui-meme, pas seulement par
    /// `lock()` : un appel egare (par ex. depuis l'editeur, si jamais il etait
    /// invoque sur une note verrouillee par erreur) ne doit jamais repeupler les
    /// champs derives tant que `isLocked` est vrai.
    @Test
    func refreshDerivedTextNeverPopulatesFieldsWhileLocked() {
        let note = Note(title: "Verrouillee", isLocked: true)
        note.blocks = [Block(order: 0, type: .paragraph, text: RichText(plainText: "Ne doit pas fuiter."), note: note)]

        note.refreshDerivedText()

        #expect(note.plainText.isEmpty)
        #expect(note.snippetText.isEmpty)
    }

    /// La suppression en cascade d'une note verrouillee doit rester identique a celle
    /// d'une note ordinaire (non-regression : le verrouillage ne doit pas interferer
    /// avec le cycle de vie SwiftData de la note ou de ses blocs).
    @Test
    func lockedNoteStillCascadeDeletesItsBlocks() throws {
        let container = try SlateContainer.make(inMemory: true)
        let context = ModelContext(container)

        let note = noteWithContent()
        note.lock()
        let block = note.blocks?.first
        context.insert(note)
        try context.save()

        context.delete(note)
        try context.save()

        let remainingBlocks = try context.fetch(FetchDescriptor<Block>())
        #expect(!remainingBlocks.contains { $0.id == block?.id })
    }
}
