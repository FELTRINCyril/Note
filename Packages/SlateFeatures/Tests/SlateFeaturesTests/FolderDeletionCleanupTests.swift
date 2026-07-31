import Foundation
import SwiftData
import Testing
import SlateModel
@testable import SlateFeatures

/// Tests de la logique pure de nettoyage de selection avant suppression d'un dossier
/// (revue de fin de Phase 3 : reference SwiftData pendante). Utilise de vrais `Folder`/
/// `Note` SwiftData (container en memoire), meme approche que
/// `SidebarTreeFlattenerTests` : aucune vue SwiftUI n'est instanciee.
@MainActor
@Suite("FolderDeletionCleanup")
struct FolderDeletionCleanupTests {

    /// Arbre de dossiers partage par plusieurs tests : Produit (racine) -> Recherche
    /// (enfant) -> Entretiens (petit-enfant), et Personnel (racine, frere de Produit).
    /// Type dedie plutot qu'un tuple : verifie la profondeur et l'absence de faux
    /// positifs sur les freres/ancetres sans depasser deux membres par tuple.
    private struct Tree {
        let produit: Folder
        let recherche: Folder
        let entretiens: Folder
        let personnel: Folder
    }

    private func makeTree(in context: ModelContext) throws -> Tree {
        let workspace = Workspace(name: "Pro")
        let space = Space(name: "Notes", workspace: workspace)
        context.insert(workspace)
        context.insert(space)

        let produit = Folder(name: "Produit", space: space)
        let recherche = Folder(name: "Recherche", space: space, parent: produit)
        let entretiens = Folder(name: "Entretiens", space: space, parent: recherche)
        let personnel = Folder(name: "Personnel", space: space)
        for folder in [produit, recherche, entretiens, personnel] { context.insert(folder) }
        try context.save()

        return Tree(produit: produit, recherche: recherche, entretiens: entretiens, personnel: personnel)
    }

    // MARK: - selectedFolder / focusedFolder

    @Test("Le dossier supprime lui-meme est nettoye")
    func clearsWhenSelectionIsTheDeletedFolderItself() throws {
        let container = try SlateContainer.make(inMemory: true)
        let context = ModelContext(container)
        let tree = try makeTree(in: context)

        let plan = FolderDeletionCleanup.plan(
            deleting: tree.produit, selectedFolder: tree.produit, selectedNote: nil, focusedFolder: tree.produit
        )

        #expect(plan.clearsSelectedFolder)
        #expect(plan.clearsFocusedFolder)
        // `selectedNote` suit `selectedFolder` (voir la documentation de
        // `FolderDeletionCleanup.plan`) : le drapeau est vrai meme si aucune note
        // n'etait selectionnee, sans effet pratique puisque `AppState.selectedNote`
        // est deja `nil`.
        #expect(plan.clearsSelectedNote)
    }

    @Test("Un enfant direct du dossier supprime est nettoye")
    func clearsWhenSelectionIsADirectChild() throws {
        let container = try SlateContainer.make(inMemory: true)
        let context = ModelContext(container)
        let tree = try makeTree(in: context)

        let plan = FolderDeletionCleanup.plan(
            deleting: tree.produit, selectedFolder: tree.recherche, selectedNote: nil, focusedFolder: tree.recherche
        )

        #expect(plan.clearsSelectedFolder)
        #expect(plan.clearsFocusedFolder)
    }

    @Test("Un petit-enfant (profondeur 2) du dossier supprime est nettoye")
    func clearsWhenSelectionIsAGrandchild() throws {
        let container = try SlateContainer.make(inMemory: true)
        let context = ModelContext(container)
        let tree = try makeTree(in: context)

        let plan = FolderDeletionCleanup.plan(
            deleting: tree.produit, selectedFolder: tree.entretiens, selectedNote: nil, focusedFolder: tree.entretiens
        )

        #expect(plan.clearsSelectedFolder)
        #expect(plan.clearsFocusedFolder)
    }

    @Test("Un frere du dossier supprime n'est jamais nettoye")
    func doesNotClearWhenSelectionIsASibling() throws {
        let container = try SlateContainer.make(inMemory: true)
        let context = ModelContext(container)
        let tree = try makeTree(in: context)

        let plan = FolderDeletionCleanup.plan(
            deleting: tree.produit, selectedFolder: tree.personnel, selectedNote: nil, focusedFolder: tree.personnel
        )

        #expect(!plan.clearsSelectedFolder)
        #expect(!plan.clearsFocusedFolder)
        #expect(!plan.clearsSelectedNote)
    }

    @Test("Un ancetre du dossier supprime n'est jamais nettoye")
    func doesNotClearWhenSelectionIsAnAncestor() throws {
        let container = try SlateContainer.make(inMemory: true)
        let context = ModelContext(container)
        let tree = try makeTree(in: context)

        // On supprime "Recherche" (l'enfant), la selection est "Produit" (le parent) :
        // le parent reste parfaitement valide apres la suppression.
        let plan = FolderDeletionCleanup.plan(
            deleting: tree.recherche, selectedFolder: tree.produit, selectedNote: nil, focusedFolder: tree.produit
        )

        #expect(!plan.clearsSelectedFolder)
        #expect(!plan.clearsFocusedFolder)
    }

    @Test("Aucune selection active : rien n'est nettoye")
    func doesNotClearWhenThereIsNoSelectionAtAll() throws {
        let container = try SlateContainer.make(inMemory: true)
        let context = ModelContext(container)
        let tree = try makeTree(in: context)

        let plan = FolderDeletionCleanup.plan(
            deleting: tree.produit, selectedFolder: nil, selectedNote: nil, focusedFolder: nil
        )

        #expect(plan == .none)
    }

    // MARK: - selectedNote

    @Test("Une note selectionnee dans un descendant du dossier supprime est nettoyee")
    func clearsSelectedNoteWhenItLivesInADescendantFolder() throws {
        let container = try SlateContainer.make(inMemory: true)
        let context = ModelContext(container)
        let tree = try makeTree(in: context)
        let note = Note(title: "Compte-rendu", folder: tree.entretiens)
        context.insert(note)
        try context.save()

        // La note est selectionnee, mais pas le dossier (ex : navigation clavier ayant
        // change `selectedFolder` sans avoir encore touche `selectedNote`) : le
        // rattachement direct de la note doit suffire a la nettoyer.
        let plan = FolderDeletionCleanup.plan(
            deleting: tree.produit, selectedFolder: nil, selectedNote: note, focusedFolder: nil
        )

        #expect(plan.clearsSelectedNote)
        #expect(!plan.clearsSelectedFolder)
    }

    @Test("Une note selectionnee ailleurs (hors du sous-arbre supprime) n'est pas nettoyee")
    func doesNotClearSelectedNoteWhenItLivesElsewhere() throws {
        let container = try SlateContainer.make(inMemory: true)
        let context = ModelContext(container)
        let tree = try makeTree(in: context)
        let note = Note(title: "Journal du jour", folder: tree.personnel)
        context.insert(note)
        try context.save()

        let plan = FolderDeletionCleanup.plan(
            deleting: tree.produit, selectedFolder: nil, selectedNote: note, focusedFolder: nil
        )

        #expect(!plan.clearsSelectedNote)
    }

    @Test("selectedNote est nettoyee quand selectedFolder l'est, meme si la note n'a pas de dossier")
    func clearsSelectedNoteWhenSelectedFolderIsClearedEvenWithoutOwnFolder() throws {
        let container = try SlateContainer.make(inMemory: true)
        let context = ModelContext(container)
        let tree = try makeTree(in: context)
        // Note delibirement sans dossier (cas degenere), pour prouver que la regle
        // "selectedNote suit selectedFolder" n'a pas besoin de `note.folder`.
        let note = Note(title: "Orpheline", folder: nil)
        context.insert(note)
        try context.save()

        let plan = FolderDeletionCleanup.plan(
            deleting: tree.produit, selectedFolder: tree.recherche, selectedNote: note, focusedFolder: nil
        )

        #expect(plan.clearsSelectedFolder)
        #expect(plan.clearsSelectedNote)
    }

    // MARK: - isFolder(_:sameAsOrDescendantOf:)

    @Test("isFolder(sameAsOrDescendantOf:) est vrai pour le dossier lui-meme et tout descendant")
    func isFolderHelperCoversSelfAndDescendants() throws {
        let container = try SlateContainer.make(inMemory: true)
        let context = ModelContext(container)
        let tree = try makeTree(in: context)

        #expect(FolderDeletionCleanup.isFolder(tree.produit, sameAsOrDescendantOf: tree.produit))
        #expect(FolderDeletionCleanup.isFolder(tree.recherche, sameAsOrDescendantOf: tree.produit))
        #expect(FolderDeletionCleanup.isFolder(tree.entretiens, sameAsOrDescendantOf: tree.produit))
        #expect(!FolderDeletionCleanup.isFolder(tree.personnel, sameAsOrDescendantOf: tree.produit))
        #expect(!FolderDeletionCleanup.isFolder(tree.produit, sameAsOrDescendantOf: tree.recherche))
    }
}
