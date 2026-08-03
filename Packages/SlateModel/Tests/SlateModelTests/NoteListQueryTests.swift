import Foundation
import SwiftData
import Testing

@testable import SlateModel

/// Tests de Phase 4 (`docs/04_liste_notes.md`, spec E3) : matiere premiere de la
/// colonne de liste de notes - portee recursive et exclusion de la corbeille
/// (coherentes avec `Folder.noteCount`), separation des epinglees, les trois criteres
/// de tri croises avec les deux directions, et la recherche (titre toujours
/// cherchable, contenu exclu pour une note verrouillee). Toute assertion passe par un
/// vrai fetch du store (`NoteListQuery` interroge `ModelContext` reellement), pas par
/// une lecture de relation deja en memoire.
@MainActor
struct NoteListQueryTests {

    /// Construit workspace -> section -> dossier racine -> sous-dossier, insere et
    /// sauvegarde. Partage par les tests qui ont besoin de la portee recursive.
    private func makeFolderTree(in context: ModelContext) throws -> (root: Folder, sub: Folder) {
        let workspace = Workspace(name: "Pro")
        let space = Space(name: "Notes", workspace: workspace)
        let root = Folder(name: "Racine", space: space)
        let sub = Folder(name: "Sous-dossier", space: space, parent: root)
        root.subfolders = [sub]
        for item in [workspace, space, root, sub] as [any PersistentModel] {
            context.insert(item)
        }
        try context.save()
        return (root, sub)
    }

    // MARK: - Portee recursive + exclusion de la corbeille

    @Test
    func notesIncludeSubfolderNotesRecursivelyAndExcludeTrash() throws {
        let container = try SlateContainer.make(inMemory: true)
        let context = ModelContext(container)
        let (root, sub) = try makeFolderTree(in: context)

        let directNote = Note(title: "Directe", folder: root)
        let nestedNote = Note(title: "Imbriquee", folder: sub)
        let trashedNote = Note(title: "A la corbeille", isTrashed: true, folder: root)
        for note in [directNote, nestedNote, trashedNote] { context.insert(note) }
        try context.save()

        let query = NoteListQuery(context: context)
        let notes = try query.notes(in: root)

        #expect(Set(notes.map(\.title)) == ["Directe", "Imbriquee"])
    }

    @Test
    func notesIsEmptyForAFolderWithOnlyTrashedNotes() throws {
        let container = try SlateContainer.make(inMemory: true)
        let context = ModelContext(container)
        let (root, _) = try makeFolderTree(in: context)

        let trashedNote = Note(title: "A la corbeille", isTrashed: true, folder: root)
        context.insert(trashedNote)
        try context.save()

        let query = NoteListQuery(context: context)
        #expect(try query.notes(in: root).isEmpty)
    }

    // MARK: - Section Epinglees separee des groupes de date

    @Test
    func pinnedFilterSeparatesPinnedNotesFromTheRest() throws {
        let container = try SlateContainer.make(inMemory: true)
        let context = ModelContext(container)
        let (root, _) = try makeFolderTree(in: context)

        let pinned = Note(title: "Epinglee", isPinned: true, folder: root)
        let regular = Note(title: "Normale", isPinned: false, folder: root)
        for note in [pinned, regular] { context.insert(note) }
        try context.save()

        let query = NoteListQuery(context: context)

        #expect(try query.notes(in: root, pinned: .pinnedOnly).map(\.title) == ["Epinglee"])
        #expect(try query.notes(in: root, pinned: .excludingPinned).map(\.title) == ["Normale"])
        #expect(Set(try query.notes(in: root, pinned: .all).map(\.title)) == ["Epinglee", "Normale"])
    }

    // MARK: - Tri : 3 criteres x 2 directions

    /// Trois notes aux valeurs de tri deliberement "croisees" : la note la plus
    /// recemment modifiee n'est pas celle creee en dernier, ni celle dont le titre
    /// est premier alphabetiquement - pour qu'un test qui trierait par le mauvais
    /// critere produise un ordre visiblement different, pas un faux positif par
    /// coincidence.
    private func makeThreeCrossedNotes(in folder: Folder, context: ModelContext) throws {
        let referenceDate = Date(timeIntervalSince1970: 1_700_000_000)
        let noteA = Note(
            title: "Zebre",
            createdAt: referenceDate,
            modifiedAt: referenceDate.addingTimeInterval(200),
            folder: folder
        )
        let noteB = Note(
            title: "Alpha",
            createdAt: referenceDate.addingTimeInterval(300),
            modifiedAt: referenceDate.addingTimeInterval(100),
            folder: folder
        )
        let noteC = Note(
            title: "Milieu",
            createdAt: referenceDate.addingTimeInterval(100),
            modifiedAt: referenceDate.addingTimeInterval(300),
            folder: folder
        )
        for note in [noteA, noteB, noteC] { context.insert(note) }
        try context.save()
    }

    @Test
    func sortsByModifiedDateAscendingAndDescending() throws {
        let container = try SlateContainer.make(inMemory: true)
        let context = ModelContext(container)
        let (root, _) = try makeFolderTree(in: context)
        try makeThreeCrossedNotes(in: root, context: context)

        let query = NoteListQuery(context: context)

        let ascending = try query.notes(in: root, sortedBy: .modifiedDate, direction: .ascending)
        #expect(ascending.map(\.title) == ["Alpha", "Zebre", "Milieu"])

        let descending = try query.notes(in: root, sortedBy: .modifiedDate, direction: .descending)
        #expect(descending.map(\.title) == ["Milieu", "Zebre", "Alpha"])
    }

    @Test
    func sortsByCreatedDateAscendingAndDescending() throws {
        let container = try SlateContainer.make(inMemory: true)
        let context = ModelContext(container)
        let (root, _) = try makeFolderTree(in: context)
        try makeThreeCrossedNotes(in: root, context: context)

        let query = NoteListQuery(context: context)

        let ascending = try query.notes(in: root, sortedBy: .createdDate, direction: .ascending)
        #expect(ascending.map(\.title) == ["Zebre", "Milieu", "Alpha"])

        let descending = try query.notes(in: root, sortedBy: .createdDate, direction: .descending)
        #expect(descending.map(\.title) == ["Alpha", "Milieu", "Zebre"])
    }

    @Test
    func sortsByTitleAscendingAndDescending() throws {
        let container = try SlateContainer.make(inMemory: true)
        let context = ModelContext(container)
        let (root, _) = try makeFolderTree(in: context)
        try makeThreeCrossedNotes(in: root, context: context)

        let query = NoteListQuery(context: context)

        let ascending = try query.notes(in: root, sortedBy: .title, direction: .ascending)
        #expect(ascending.map(\.title) == ["Alpha", "Milieu", "Zebre"])

        let descending = try query.notes(in: root, sortedBy: .title, direction: .descending)
        #expect(descending.map(\.title) == ["Zebre", "Milieu", "Alpha"])
    }

    // MARK: - Recherche : titre, contenu, et exclusion du contenu d'une note verrouillee

    @Test
    func searchFindsNoteByTitle() throws {
        let container = try SlateContainer.make(inMemory: true)
        let context = ModelContext(container)
        let (root, _) = try makeFolderTree(in: context)

        let matching = Note(title: "Budget 2027", folder: root)
        let other = Note(title: "Autre chose", folder: root)
        for note in [matching, other] { context.insert(note) }
        try context.save()

        let query = NoteListQuery(context: context)
        let results = try query.notes(in: root, matching: "budget")

        #expect(results.map(\.title) == ["Budget 2027"])
    }

    @Test
    func searchFindsNoteByContentWhenNotLocked() throws {
        let container = try SlateContainer.make(inMemory: true)
        let context = ModelContext(container)
        let (root, _) = try makeFolderTree(in: context)

        let matching = Note(title: "Sans rapport", folder: root)
        matching.plainText = "Un passage qui mentionne stencil quelque part."
        let other = Note(title: "Autre", folder: root)
        other.plainText = "Rien a voir."
        for note in [matching, other] { context.insert(note) }
        try context.save()

        let query = NoteListQuery(context: context)
        let results = try query.notes(in: root, matching: "stencil")

        #expect(results.map(\.title) == ["Sans rapport"])
    }

    @Test
    func searchExcludesContentOfALockedNoteButStillFindsItsTitle() throws {
        let container = try SlateContainer.make(inMemory: true)
        let context = ModelContext(container)
        let (root, _) = try makeFolderTree(in: context)

        let lockedNote = Note(title: "Budget 2027", isLocked: true, folder: root)
        lockedNote.plainText = "Chiffres confidentiels : stencil interne."
        let unlockedNote = Note(title: "Notes libres", isLocked: false, folder: root)
        unlockedNote.plainText = "Rien a voir avec le sujet recherche."
        for note in [lockedNote, unlockedNote] { context.insert(note) }
        try context.save()

        let query = NoteListQuery(context: context)

        // Le contenu de la note verrouillee ne doit JAMAIS la faire remonter par
        // recherche sur son contenu.
        #expect(try query.notes(in: root, matching: "stencil").isEmpty)

        // Mais son titre, lui, reste cherchable.
        #expect(try query.notes(in: root, matching: "budget").map(\.title) == ["Budget 2027"])
    }

    @Test
    func emptyOrBlankSearchQueryReturnsEveryNote() throws {
        let container = try SlateContainer.make(inMemory: true)
        let context = ModelContext(container)
        let (root, _) = try makeFolderTree(in: context)

        let noteOne = Note(title: "Un", folder: root)
        let noteTwo = Note(title: "Deux", folder: root)
        for note in [noteOne, noteTwo] { context.insert(note) }
        try context.save()

        let query = NoteListQuery(context: context)
        #expect(try query.notes(in: root, matching: "   ").count == 2)
        #expect(try query.notes(in: root, matching: nil).count == 2)
    }
}
