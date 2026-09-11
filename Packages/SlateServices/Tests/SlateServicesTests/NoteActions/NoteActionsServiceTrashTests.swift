import Foundation
import SlateModel
import SwiftData
import Testing

@testable import SlateServices

/// Tests de Phase 11 (`docs/11_organisation_notes.md`) sur le cycle de corbeille et
/// la purge automatique : l'autre point de rigueur explicitement demande (suppression
/// definitive sans orphelin, bornes exactes de la purge a J-29/30/31).
@MainActor
struct NoteActionsServiceTrashTests {
    private let service = NoteActionsService()

    // MARK: - Cycle corbeille

    @Test
    func trashThenRestoreRoundTrips() {
        let note = Note(title: "Note")
        let now = Date(timeIntervalSince1970: 1_000_000)

        service.moveToTrash(note, now: now)
        #expect(note.isTrashed)
        #expect(note.trashedAt == now)

        service.restore(note)
        #expect(!note.isTrashed)
        #expect(note.trashedAt == nil)
    }

    @Test
    func trashThenDeletePermanentlyRemovesNoteBlocksAndAttachmentsFromStore() throws {
        let container = try SlateContainer.make(inMemory: true)
        let context = ModelContext(container)
        let note = NoteActionsFixtures.makeRichNote(in: context)

        service.moveToTrash(note)
        try context.save()

        let blocksBefore = try context.fetch(FetchDescriptor<Block>())
        #expect(!blocksBefore.isEmpty)
        let attachmentsBefore = try context.fetch(FetchDescriptor<SlateModel.Attachment>())
        #expect(!attachmentsBefore.isEmpty)

        service.deletePermanently(note, in: context)
        try context.save()

        // Verification par un vrai fetch, pas par inspection de la relation en
        // memoire : c'est la seule preuve honnete qu'aucun bloc ni piece jointe ne
        // reste orphelin dans le store (meme motif que `EntityGraphTests` et
        // `EditorControllerDeletionPurgeTests`).
        let notesAfter = try context.fetch(FetchDescriptor<Note>())
        #expect(notesAfter.isEmpty)
        let blocksAfter = try context.fetch(FetchDescriptor<Block>())
        #expect(blocksAfter.isEmpty)
        let attachmentsAfter = try context.fetch(FetchDescriptor<SlateModel.Attachment>())
        #expect(attachmentsAfter.isEmpty)
    }

    // MARK: - Purge automatique : bornes exactes

    @Test
    func purgeExpiredTrashDeletesNoteTrashedExactlyThirtyOneDaysAgo() throws {
        let container = try SlateContainer.make(inMemory: true)
        let context = ModelContext(container)
        let now = Date(timeIntervalSince1970: 100_000_000)
        let note = NoteActionsFixtures.makeRichNote(in: context)
        service.moveToTrash(note, now: NoteActionsFixtures.daysBefore(31, from: now))
        try context.save()

        let purgedCount = try service.purgeExpiredTrash(in: context, now: now)

        #expect(purgedCount == 1)
        let notesAfter = try context.fetch(FetchDescriptor<Note>())
        #expect(notesAfter.isEmpty)
        let blocksAfter = try context.fetch(FetchDescriptor<Block>())
        #expect(blocksAfter.isEmpty)
    }

    @Test
    func purgeExpiredTrashKeepsNoteTrashedExactlyThirtyDaysAgo() throws {
        let container = try SlateContainer.make(inMemory: true)
        let context = ModelContext(container)
        let now = Date(timeIntervalSince1970: 100_000_000)
        let note = NoteActionsFixtures.makeRichNote(in: context)
        service.moveToTrash(note, now: NoteActionsFixtures.daysBefore(30, from: now))
        try context.save()

        let purgedCount = try service.purgeExpiredTrash(in: context, now: now)

        #expect(purgedCount == 0)
        let notesAfter = try context.fetch(FetchDescriptor<Note>())
        #expect(notesAfter.count == 1)
    }

    @Test
    func purgeExpiredTrashKeepsNoteTrashedTwentyNineDaysAgo() throws {
        let container = try SlateContainer.make(inMemory: true)
        let context = ModelContext(container)
        let now = Date(timeIntervalSince1970: 100_000_000)
        let note = NoteActionsFixtures.makeRichNote(in: context)
        service.moveToTrash(note, now: NoteActionsFixtures.daysBefore(29, from: now))
        try context.save()

        let purgedCount = try service.purgeExpiredTrash(in: context, now: now)

        #expect(purgedCount == 0)
        let notesAfter = try context.fetch(FetchDescriptor<Note>())
        #expect(notesAfter.count == 1)
    }

    @Test
    func purgeExpiredTrashNeverTouchesNoteWithNilTrashedAt() throws {
        let container = try SlateContainer.make(inMemory: true)
        let context = ModelContext(container)
        let note = NoteActionsFixtures.makeRichNote(in: context)
        // Etat incoherent volontaire (isTrashed sans trashedAt) : le predicat de purge
        // doit rester defensif meme face a une donnee qui ne devrait jamais exister.
        note.isTrashed = true
        note.trashedAt = nil
        try context.save()

        let purgedCount = try service.purgeExpiredTrash(in: context, now: .now)

        #expect(purgedCount == 0)
        let notesAfter = try context.fetch(FetchDescriptor<Note>())
        #expect(notesAfter.count == 1)
    }

    @Test
    func purgeExpiredTrashNeverTouchesNonTrashedNote() throws {
        let container = try SlateContainer.make(inMemory: true)
        let context = ModelContext(container)
        let note = NoteActionsFixtures.makeRichNote(in: context)
        #expect(!note.isTrashed)

        let purgedCount = try service.purgeExpiredTrash(in: context, now: .now)

        #expect(purgedCount == 0)
        let notesAfter = try context.fetch(FetchDescriptor<Note>())
        #expect(notesAfter.count == 1)
    }

    @Test
    func purgeExpiredTrashLeavesUntouchedNotesAlone() throws {
        let container = try SlateContainer.make(inMemory: true)
        let context = ModelContext(container)
        let now = Date(timeIntervalSince1970: 100_000_000)

        let expiredNote = Note(title: "Expiree")
        context.insert(expiredNote)
        service.moveToTrash(expiredNote, now: NoteActionsFixtures.daysBefore(60, from: now))

        let freshTrashedNote = Note(title: "Recente")
        context.insert(freshTrashedNote)
        service.moveToTrash(freshTrashedNote, now: NoteActionsFixtures.daysBefore(1, from: now))

        let activeNote = Note(title: "Active")
        context.insert(activeNote)
        try context.save()

        let purgedCount = try service.purgeExpiredTrash(in: context, now: now)

        #expect(purgedCount == 1)
        let remainingTitles = Set(try context.fetch(FetchDescriptor<Note>()).map(\.title))
        #expect(remainingTitles == ["Recente", "Active"])
    }
}
