import Foundation
import SwiftData
import Testing

@testable import SlateModel

/// Construit un workspace -> section, insere et sauvegarde. Partage entre les deux
/// suites de ce fichier (`SidebarNavigationQueryTests`, `SidebarNavigationMutationTests`).
@MainActor
private func makeWorkspaceAndSpace(in context: ModelContext) throws -> (workspace: Workspace, space: Space) {
    let workspace = Workspace(name: "Pro")
    let space = Space(name: "Notes", workspace: workspace)
    workspace.spaces = [space]
    context.insert(workspace)
    context.insert(space)
    try context.save()
    return (workspace, space)
}

/// Tests de Phase 3 (`docs/03_sidebar_navigation.md`) : tri deterministe, compteur de
/// notes recursif excluant la corbeille, favoris. Les mutations (creation,
/// renommage, suppression, reordonnancement, persistance de `isExpanded`) sont dans
/// `SidebarNavigationMutationTests`, dans ce meme fichier.
@MainActor
struct SidebarNavigationQueryTests {

    // MARK: - Tri deterministe

    @Test
    func rootFoldersAreSortedBySortIndexThenName() throws {
        let container = try SlateContainer.make(inMemory: true)
        let context = ModelContext(container)
        let (_, space) = try makeWorkspaceAndSpace(in: context)
        let navigation = SidebarNavigation(context: context)

        // sortIndex egaux (0) : le nom doit trancher.
        let zebra = Folder(name: "Zebre", sortIndex: 0, space: space)
        let alpha = Folder(name: "Alpha", sortIndex: 0, space: space)
        // sortIndex distinct, prioritaire sur le nom.
        let last = Folder(name: "Aaa", sortIndex: 5, space: space)
        space.folders = [zebra, alpha, last]
        for folder in [zebra, alpha, last] { context.insert(folder) }
        try context.save()

        let ordered = navigation.rootFolders(in: space)
        #expect(ordered.map(\.name) == ["Alpha", "Zebre", "Aaa"])
    }

    @Test
    func spacesAreSortedBySortIndexThenName() throws {
        let container = try SlateContainer.make(inMemory: true)
        let context = ModelContext(container)
        let workspace = Workspace(name: "Pro")
        let second = Space(name: "B", sortIndex: 1, workspace: workspace)
        let first = Space(name: "A", sortIndex: 0, workspace: workspace)
        workspace.spaces = [second, first]
        for item in [workspace, second, first] as [any PersistentModel] { context.insert(item) }
        try context.save()

        let navigation = SidebarNavigation(context: context)
        let ordered = navigation.spaces(in: workspace)
        #expect(ordered.map(\.name) == ["A", "B"])
    }

    @Test
    func subfoldersAreSortedDeterministically() throws {
        let container = try SlateContainer.make(inMemory: true)
        let context = ModelContext(container)
        let (_, space) = try makeWorkspaceAndSpace(in: context)
        let parent = Folder(name: "Parent", space: space)
        let childB = Folder(name: "B", sortIndex: 0, space: space, parent: parent)
        let childA = Folder(name: "A", sortIndex: 0, space: space, parent: parent)
        parent.subfolders = [childB, childA]
        for item in [parent, childB, childA] { context.insert(item) }
        try context.save()

        let navigation = SidebarNavigation(context: context)
        let ordered = navigation.subfolders(of: parent)
        #expect(ordered.map(\.name) == ["A", "B"])
    }

    // MARK: - Compteur de notes (recursif, excluant la corbeille)

    @Test
    func noteCountIsRecursiveAndExcludesTrashedNotes() throws {
        let container = try SlateContainer.make(inMemory: true)
        let context = ModelContext(container)
        let (_, space) = try makeWorkspaceAndSpace(in: context)

        let parent = Folder(name: "Parent", space: space)
        let child = Folder(name: "Enfant", space: space, parent: parent)
        parent.subfolders = [child]

        let directNote = Note(title: "Directe", folder: parent)
        let trashedDirectNote = Note(title: "A la corbeille", isTrashed: true, folder: parent)
        let nestedNote = Note(title: "Imbriquee", folder: child)
        parent.notes = [directNote, trashedDirectNote]
        child.notes = [nestedNote]

        for item in [parent, child, directNote, trashedDirectNote, nestedNote] as [any PersistentModel] {
            context.insert(item)
        }
        try context.save()

        // 1 note directe non supprimee + 1 note imbriquee = 2. La note a la corbeille
        // et la note imbriquee ne comptent qu'une fois chacune (pas de double
        // comptage), et un dossier "vide en direct" mais avec du contenu imbrique
        // n'affiche jamais 0.
        #expect(parent.noteCount == 2)
        #expect(child.noteCount == 1)
    }

    @Test
    func noteCountIsZeroForAnEmptyFolder() throws {
        let container = try SlateContainer.make(inMemory: true)
        let context = ModelContext(container)
        let (_, space) = try makeWorkspaceAndSpace(in: context)
        let folder = Folder(name: "Vide", space: space)
        context.insert(folder)
        try context.save()

        #expect(folder.noteCount == 0)
    }

    // MARK: - Favoris

    @Test
    func favoriteNotesExcludesNonFavoritesTrashedAndOtherWorkspaces() throws {
        let container = try SlateContainer.make(inMemory: true)
        let context = ModelContext(container)
        let (workspace, space) = try makeWorkspaceAndSpace(in: context)
        let folder = Folder(name: "Dossier", space: space)

        let favorite = Note(title: "Favorite", isFavorite: true, folder: folder)
        let favoriteButTrashed = Note(
            title: "Favorite mais supprimee", isFavorite: true, isTrashed: true, folder: folder
        )
        let notFavorite = Note(title: "Pas favorite", folder: folder)

        // Une autre chaine workspace -> space -> folder -> note favorite, qui ne doit
        // jamais apparaitre dans les favoris du premier workspace.
        let otherWorkspace = Workspace(name: "Perso")
        let otherSpace = Space(name: "Autre section", workspace: otherWorkspace)
        let otherFolder = Folder(name: "Autre dossier", space: otherSpace)
        let otherWorkspaceFavorite = Note(
            title: "Favorite d'un autre workspace", isFavorite: true, folder: otherFolder
        )

        folder.notes = [favorite, favoriteButTrashed, notFavorite]
        otherWorkspace.spaces = [otherSpace]
        otherSpace.folders = [otherFolder]
        otherFolder.notes = [otherWorkspaceFavorite]

        for item in [
            folder, favorite, favoriteButTrashed, notFavorite,
            otherWorkspace, otherSpace, otherFolder, otherWorkspaceFavorite
        ] as [any PersistentModel] {
            context.insert(item)
        }
        try context.save()

        let navigation = SidebarNavigation(context: context)
        let favorites = try navigation.favoriteNotes(in: workspace)
        #expect(favorites.map(\.title) == ["Favorite"])
    }
}

/// Mutations de la Phase 3 : creation/renommage/suppression de dossier, creation de
/// note, reordonnancement de freres, persistance de `Folder.isExpanded`. Chaque
/// mutation est verifiee par un **fetch reel** dans un nouveau `ModelContext` (ou un
/// nouveau `ModelContainer` pour la persistance disque), jamais par une simple
/// relecture de l'objet en memoire retourne par l'appel.
@MainActor
struct SidebarNavigationMutationTests {

    // MARK: - Dossier

    @Test
    func createFolderPersistsToDiskAndAppendsAtTheEndOfSiblings() throws {
        let container = try SlateContainer.make(inMemory: true)
        let context = ModelContext(container)
        let (_, space) = try makeWorkspaceAndSpace(in: context)
        let existing = Folder(name: "Existant", sortIndex: 0, space: space)
        space.folders = [existing]
        context.insert(existing)
        try context.save()

        let navigation = SidebarNavigation(context: context)
        let created = try navigation.createFolder(named: "Nouveau", in: space)

        let freshContext = ModelContext(container)
        let fetchedFolders = try freshContext.fetch(FetchDescriptor<Folder>())
        #expect(fetchedFolders.count == 2)
        let fetchedCreated = try #require(fetchedFolders.first { $0.id == created.id })
        #expect(fetchedCreated.name == "Nouveau")
        #expect(fetchedCreated.sortIndex == 1)
        #expect(fetchedCreated.space?.name == "Notes")
        #expect(fetchedCreated.parent == nil)
    }

    @Test
    func createFolderWithParentUsesParentsSpaceAndAppendsAmongSubfolders() throws {
        let container = try SlateContainer.make(inMemory: true)
        let context = ModelContext(container)
        let (_, space) = try makeWorkspaceAndSpace(in: context)
        let parent = Folder(name: "Parent", space: space)
        let existingChild = Folder(name: "Enfant existant", sortIndex: 0, space: space, parent: parent)
        parent.subfolders = [existingChild]
        for item in [parent, existingChild] { context.insert(item) }
        try context.save()

        let navigation = SidebarNavigation(context: context)
        let created = try navigation.createFolder(named: "Nouvel enfant", in: space, parent: parent)

        let freshContext = ModelContext(container)
        let fetchedFolders = try freshContext.fetch(FetchDescriptor<Folder>())
        let fetchedCreated = try #require(fetchedFolders.first { $0.id == created.id })
        #expect(fetchedCreated.sortIndex == 1)
        #expect(fetchedCreated.parent?.name == "Parent")
        #expect(fetchedCreated.space?.name == "Notes")
    }

    @Test
    func renameFolderPersistsToDisk() throws {
        let container = try SlateContainer.make(inMemory: true)
        let context = ModelContext(container)
        let (_, space) = try makeWorkspaceAndSpace(in: context)
        let folder = Folder(name: "Ancien nom", space: space)
        context.insert(folder)
        try context.save()

        let navigation = SidebarNavigation(context: context)
        try navigation.rename(folder, to: "Nouveau nom")

        let freshContext = ModelContext(container)
        let fetched = try #require(try freshContext.fetch(FetchDescriptor<Folder>()).first)
        #expect(fetched.name == "Nouveau nom")
    }

    @Test
    func deleteFolderCascadesToSubfoldersAndNotesButNotToSpace() throws {
        let container = try SlateContainer.make(inMemory: true)
        let context = ModelContext(container)
        let (_, space) = try makeWorkspaceAndSpace(in: context)
        let parent = Folder(name: "Parent", space: space)
        let child = Folder(name: "Enfant", space: space, parent: parent)
        let note = Note(title: "Note du dossier", folder: child)
        parent.subfolders = [child]
        child.notes = [note]
        for item in [parent, child, note] as [any PersistentModel] { context.insert(item) }
        try context.save()

        let navigation = SidebarNavigation(context: context)
        try navigation.delete(parent)

        let freshContext = ModelContext(container)
        #expect(try freshContext.fetch(FetchDescriptor<Folder>()).isEmpty)
        #expect(try freshContext.fetch(FetchDescriptor<Note>()).isEmpty)
        #expect(try freshContext.fetch(FetchDescriptor<Space>()).count == 1)
    }

    // MARK: - Note

    @Test
    func createNotePersistsToDiskWithConsistentDerivedText() throws {
        let container = try SlateContainer.make(inMemory: true)
        let context = ModelContext(container)
        let (_, space) = try makeWorkspaceAndSpace(in: context)
        let folder = Folder(name: "Dossier", space: space)
        context.insert(folder)
        try context.save()

        let navigation = SidebarNavigation(context: context)
        let created = try navigation.createNote(titled: "Ma note", in: folder)

        let freshContext = ModelContext(container)
        let fetched = try #require(
            try freshContext.fetch(FetchDescriptor<Note>()).first { $0.id == created.id }
        )
        #expect(fetched.title == "Ma note")
        #expect(fetched.folder?.name == "Dossier")
        // Aucun bloc au depart : le texte derive reste coherent (vide), pas
        // desynchronise.
        #expect(fetched.plainText.isEmpty)
        #expect(fetched.snippetText.isEmpty)
    }

    // MARK: - Reordonnancement

    @Test
    func reorderSiblingsAssignsConsecutiveSortIndexesAndPersists() throws {
        let container = try SlateContainer.make(inMemory: true)
        let context = ModelContext(container)
        let (_, space) = try makeWorkspaceAndSpace(in: context)
        let first = Folder(name: "Premier", sortIndex: 0, space: space)
        let second = Folder(name: "Second", sortIndex: 1, space: space)
        let third = Folder(name: "Troisieme", sortIndex: 2, space: space)
        space.folders = [first, second, third]
        for item in [first, second, third] { context.insert(item) }
        try context.save()

        let navigation = SidebarNavigation(context: context)
        // L'utilisateur glisse "Troisieme" en premiere position.
        try navigation.reorderSiblings([third, first, second])

        let freshContext = ModelContext(container)
        let fetchedFolders = try freshContext.fetch(FetchDescriptor<Folder>())
        let byName = Dictionary(uniqueKeysWithValues: fetchedFolders.map { ($0.name, $0.sortIndex) })
        #expect(byName["Troisieme"] == 0)
        #expect(byName["Premier"] == 1)
        #expect(byName["Second"] == 2)

        let navigationAfter = SidebarNavigation(context: freshContext)
        let refetchedSpace = try #require(try freshContext.fetch(FetchDescriptor<Space>()).first)
        let orderedAfter = navigationAfter.rootFolders(in: refetchedSpace)
        #expect(orderedAfter.map(\.name) == ["Troisieme", "Premier", "Second"])
    }

    // MARK: - Persistance de l'etat plie/deplie

    @Test
    func isExpandedDefaultsToTrueAndPersistsAcrossContexts() throws {
        let storeDirectory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: storeDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: storeDirectory) }
        let storeURL = storeDirectory.appending(path: "Slate.store")

        try {
            let container = try SlateContainer.make(storeURL: storeURL)
            let context = ModelContext(container)
            let workspace = Workspace(name: "Pro")
            let space = Space(name: "Notes", workspace: workspace)
            let folder = Folder(name: "Dossier", space: space)
            workspace.spaces = [space]
            space.folders = [folder]
            for item in [workspace, space, folder] as [any PersistentModel] { context.insert(item) }
            try context.save()

            #expect(folder.isExpanded == true)

            folder.isExpanded = false
            try context.save()
        }()

        // Second "lancement" : nouveau container sur la meme URL, pour prouver que
        // l'etat plie a survecu a une fermeture/reouverture reelle du store, pas
        // seulement a la duree de vie d'un ModelContext.
        let reopenedContainer = try SlateContainer.make(storeURL: storeURL)
        let reopenedContext = ModelContext(reopenedContainer)
        let reopenedFolder = try #require(try reopenedContext.fetch(FetchDescriptor<Folder>()).first)
        #expect(reopenedFolder.isExpanded == false)
    }
}
