import Foundation
import SwiftData
import Testing
import SlateModel
@testable import SlateFeatures

/// Tests de la logique pure d'aplatissement de l'arbre de dossiers (indentation,
/// ordre d'affichage, respect de l'etat plie/deplie). Utilise de vrais `Folder`
/// SwiftData (container en memoire) car `SidebarTreeFlattener` opere sur ce type,
/// mais aucune vue SwiftUI n'est instanciee : c'est la meme approche que
/// `SlateModelTests`.
@MainActor
@Suite("SidebarTreeFlattener")
struct SidebarTreeFlattenerTests {

    @Test("Ordre et indentation d'un arbre a deux niveaux, tout deplie")
    func flattenOrdersAndIndentsExpandedTree() throws {
        let container = try SlateContainer.make(inMemory: true)
        let context = ModelContext(container)
        let workspace = Workspace(name: "Pro")
        let space = Space(name: "Notes", workspace: workspace)
        context.insert(workspace)
        context.insert(space)

        let produit = Folder(name: "Produit", sortIndex: 0, space: space)
        let recherche = Folder(name: "Recherche", sortIndex: 0, space: space, parent: produit)
        let entretiens = Folder(name: "Entretiens", sortIndex: 0, space: space, parent: recherche)
        let personnel = Folder(name: "Personnel", sortIndex: 1, space: space)
        for folder in [produit, recherche, entretiens, personnel] { context.insert(folder) }
        try context.save()

        let childrenByParentID: [UUID: [Folder]] = [
            produit.id: [recherche],
            recherche.id: [entretiens]
        ]

        let entries = SidebarTreeFlattener.flatten(rootFolders: [produit, personnel]) { folder in
            childrenByParentID[folder.id] ?? []
        }

        #expect(entries.map(\.folder.name) == ["Produit", "Recherche", "Entretiens", "Personnel"])
        #expect(entries.map(\.indentLevel) == [0, 1, 2, 0])
    }

    @Test("Un dossier replie n'expose pas ses enfants dans le resultat")
    func collapsedFolderHidesChildren() throws {
        let container = try SlateContainer.make(inMemory: true)
        let context = ModelContext(container)
        let workspace = Workspace(name: "Pro")
        let space = Space(name: "Notes", workspace: workspace)
        context.insert(workspace)
        context.insert(space)

        let parent = Folder(name: "Parent", isExpanded: false, space: space)
        let child = Folder(name: "Enfant", space: space, parent: parent)
        context.insert(parent)
        context.insert(child)
        try context.save()

        let entries = SidebarTreeFlattener.flatten(rootFolders: [parent]) { folder in
            folder.id == parent.id ? [child] : []
        }

        #expect(entries.map(\.folder.name) == ["Parent"])
    }

    @Test("Un dossier deplie sans enfants ne produit aucune entree supplementaire")
    func expandedLeafFolderProducesNoExtraEntries() throws {
        let container = try SlateContainer.make(inMemory: true)
        let context = ModelContext(container)
        let workspace = Workspace(name: "Pro")
        let space = Space(name: "Notes", workspace: workspace)
        context.insert(workspace)
        context.insert(space)

        let leaf = Folder(name: "Journal", isExpanded: true, space: space)
        context.insert(leaf)
        try context.save()

        let entries = SidebarTreeFlattener.flatten(rootFolders: [leaf]) { _ in [] }

        #expect(entries.map(\.folder.name) == ["Journal"])
        #expect(entries.map(\.indentLevel) == [0])
    }
}
