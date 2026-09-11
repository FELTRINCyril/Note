import Foundation
import SlateModel
import SwiftData
import Testing

@testable import SlateServices

/// Tests de Phase 11 (`docs/11_organisation_notes.md`) sur le deplacement,
/// epingle/favori, et le calcul du nombre de jours restants avant purge.
@MainActor
struct NoteActionsServiceMiscTests {
    private let service = NoteActionsService()

    // MARK: - Deplacement

    @Test
    func moveChangesFolder() throws {
        let container = try SlateContainer.make(inMemory: true)
        let context = ModelContext(container)
        let sourceFolder = Folder(name: "A")
        let destinationFolder = Folder(name: "B")
        context.insert(sourceFolder)
        context.insert(destinationFolder)
        let note = Note(title: "Note", folder: sourceFolder)
        context.insert(note)
        try context.save()

        service.move(note, to: destinationFolder)

        #expect(note.folder?.id == destinationFolder.id)
    }

    // MARK: - Epingle / favori

    @Test
    func setPinnedTogglesFlag() {
        let note = Note(title: "Note")
        service.setPinned(true, for: note)
        #expect(note.isPinned)
        service.setPinned(false, for: note)
        #expect(!note.isPinned)
    }

    @Test
    func setFavoriteTogglesFlag() {
        let note = Note(title: "Note")
        service.setFavorite(true, for: note)
        #expect(note.isFavorite)
        service.setFavorite(false, for: note)
        #expect(!note.isFavorite)
    }

    // MARK: - Expiration restante

    @Test
    func daysRemainingBeforePurgeMatchesDesignExamples() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "UTC"))
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 9, day: 11)))

        // "Supprimee il y a 2 jours ... expire dans 28 jours" (artboard B).
        let note = Note(title: "Note")
        note.isTrashed = true
        note.trashedAt = calendar.date(byAdding: .day, value: -2, to: now)

        let remaining = service.daysRemainingBeforePurge(for: note, now: now, calendar: calendar)
        #expect(remaining == 28)
    }

    @Test
    func daysRemainingBeforePurgeReturnsNilWhenNotTrashed() {
        let note = Note(title: "Note")
        #expect(service.daysRemainingBeforePurge(for: note) == nil)
    }
}
