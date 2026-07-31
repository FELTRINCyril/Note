import Foundation
import SwiftData
import Testing

@testable import SlateModel

/// Tests de persistance de Phase 1 : valident uniquement que la pile SwiftData
/// fonctionne avec le modele placeholder `Note`. Pas de couverture du vrai schema
/// (Phase 2).
@MainActor
struct PersistenceTests {

    @Test
    func containerCreationInMemorySucceeds() throws {
        _ = try SlateContainer.make(inMemory: true)
    }

    @Test
    func insertingAndFetchingNoteRoundTripsTitle() throws {
        let container = try SlateContainer.make(inMemory: true)
        let context = ModelContext(container)

        let note = Note(title: "Ma premiere note")
        context.insert(note)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<Note>())
        #expect(fetched.count == 1)
        #expect(fetched.first?.title == "Ma premiere note")
    }

    @Test
    func deletingNoteRemovesItFromStore() throws {
        let container = try SlateContainer.make(inMemory: true)
        let context = ModelContext(container)

        let note = Note(title: "A supprimer")
        context.insert(note)
        try context.save()

        let inserted = try context.fetch(FetchDescriptor<Note>())
        #expect(inserted.count == 1)

        if let toDelete = inserted.first {
            context.delete(toDelete)
            try context.save()
        }

        let remaining = try context.fetch(FetchDescriptor<Note>())
        #expect(remaining.isEmpty)
    }

    @Test
    func cloudKitIsDisabledInDebugBuilds() {
        // Les tests tournent en configuration Debug : le flag SLATE_CLOUDKIT n'est
        // defini qu'en Release (voir project.yml et docs/01_setup_projet.md 1.4).
        #expect(SlateContainer.isCloudKitEnabled == false)
    }
}
