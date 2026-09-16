import Foundation
import SwiftData
import Testing
import SlateModel
@testable import SlateFeatures

/// Creation et ouverture d'une base PLEINE PAGE (Phase 17, "les deux hebergements") :
/// `DatabaseFolderCreation.makeDatabase(in:)` produit une base immediatement utilisable
/// (au moins un champ), reellement rattachee au dossier une fois inseree/sauvegardee, et
/// `AppState.selectedDatabase` est le point d'"ouverture" consomme par
/// `NoteDetailColumnView` -- mutuellement exclusif avec `selectedNote` (un seul document
/// affiche a la fois dans la colonne detail).
@MainActor
@Suite("DatabaseFolderCreation / ouverture pleine page")
struct DatabaseFolderCreationTests {
    private func makeFolder(in context: ModelContext) throws -> Folder {
        let workspace = Workspace(name: "Pro")
        let space = Space(name: "Notes", workspace: workspace)
        let folder = Folder(name: "Projets", space: space)
        context.insert(workspace)
        context.insert(space)
        context.insert(folder)
        try context.save()
        return folder
    }

    @Test("makeDatabase(in:) cree une base pleine page prete a l'emploi, rattachee au dossier")
    func makeDatabaseCreatesUsableFullPageDatabase() throws {
        let container = try SlateContainer.make(inMemory: true)
        let context = ModelContext(container)
        let folder = try makeFolder(in: context)

        let created = DatabaseFolderCreation.makeDatabase(in: folder, name: "Suivi", firstFieldName: "Nom")
        context.insert(created.database)
        context.insert(created.firstField)
        try context.save()

        #expect(created.database.hostMode == .fullPage)
        #expect(created.database.folder?.id == folder.id)
        #expect(created.database.fields?.count == 1)
        #expect(created.database.fields?.first?.fieldType == .text)
        #expect(folder.databases?.contains { $0.id == created.database.id } == true)

        // Reellement persistee (pas seulement rattachee en memoire) : un vrai fetch
        // apres `save()` doit la retrouver, meme motif que `EditorControllerDatabaseCommandTests`.
        let fetchedDatabases = try context.fetch(FetchDescriptor<Database>())
        #expect(fetchedDatabases.contains { $0.id == created.database.id })
    }

    @Test("Selectionner une base ouvre la colonne detail dessus et deselectionne la note en cours")
    func selectingDatabaseOpensItAndClearsSelectedNote() throws {
        let container = try SlateContainer.make(inMemory: true)
        let context = ModelContext(container)
        let folder = try makeFolder(in: context)
        let note = Note(title: "Une note", folder: folder)
        context.insert(note)
        try context.save()

        let appState = AppState()
        appState.selectedNote = note
        #expect(appState.selectedNote?.id == note.id)

        let created = DatabaseFolderCreation.makeDatabase(in: folder, name: "Suivi", firstFieldName: "Nom")
        context.insert(created.database)
        context.insert(created.firstField)
        try context.save()

        appState.selectedDatabase = created.database

        #expect(appState.selectedDatabase?.id == created.database.id)
        #expect(appState.selectedNote == nil)
    }

    @Test("Selectionner une note referme la base pleine page ouverte")
    func selectingNoteClosesOpenDatabase() throws {
        let container = try SlateContainer.make(inMemory: true)
        let context = ModelContext(container)
        let folder = try makeFolder(in: context)
        let note = Note(title: "Une note", folder: folder)
        context.insert(note)
        let created = DatabaseFolderCreation.makeDatabase(in: folder, name: "Suivi", firstFieldName: "Nom")
        context.insert(created.database)
        context.insert(created.firstField)
        try context.save()

        let appState = AppState()
        appState.selectedDatabase = created.database
        #expect(appState.selectedDatabase != nil)

        appState.selectedNote = note

        #expect(appState.selectedNote?.id == note.id)
        #expect(appState.selectedDatabase == nil)
    }
}
