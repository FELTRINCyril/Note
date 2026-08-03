import Foundation
import SwiftData
import Testing

@testable import SlateModel

/// Preuve empirique que l'ajout de `Folder.colorIndex` (arbitrage 2 de Cyril, Phase 4)
/// est une migration legere automatique de SwiftData, sans bump de version de schema -
/// meme raisonnement et meme technique que `FolderExpandedStateMigrationTests`
/// (Phase 3, ajout de `isExpanded`), documente dans `SlateSchema.swift`.
///
/// Difference notable avec `Folder.isExpanded` : `colorIndex` est **optionnel**
/// (`Int?`), pas une propriete avec valeur par defaut. C'est une categorie additive
/// legerement differente (colonne SQLite nullable plutot que colonne NOT NULL avec
/// defaut), donc une preuve dediee a cette forme precise a de la valeur - elle ne se
/// deduit pas automatiquement de la preuve deja faite pour `isExpanded`.
///
/// Ce test ouvre, avec le **vrai** `SlateContainer` de production, un store construit
/// avec la forme de `Folder` telle qu'elle existait juste avant cette tache (avec
/// `isExpanded`, sans `colorIndex`), pour simuler fidelement le store deja present sur
/// la machine de Cyril.
@MainActor
struct FolderColorIndexMigrationTests {

    /// Reproduction figee, a but de test uniquement, de la forme de `Folder` juste
    /// avant l'ajout de `colorIndex` (donc apres l'ajout de `isExpanded` en Phase 3).
    /// Meme technique de nommage que `FolderExpandedStateMigrationTests` : les types
    /// prives portent les memes noms courts (`Workspace`/`Space`/`Folder`) dans un
    /// espace de noms dedie, pour que SwiftData les fasse correspondre aux memes
    /// tables SQLite ("Workspace"/"Space"/"Folder") que le vrai `SlateModel`.
    fileprivate enum LegacyBeforeColorIndex {
        @Model
        final class Workspace {
            var id: UUID = UUID()
            var name: String = ""
            var iconName: String = "square.stack"
            var accentColorHex: String = "#0A84FF"
            var createdAt: Date = Date.now
            var sortIndex: Int = 0

            @Relationship(deleteRule: .cascade, inverse: \Space.workspace)
            var spaces: [Space]? = []

            init(name: String = "") {
                self.name = name
            }
        }

        @Model
        final class Space {
            var id: UUID = UUID()
            var name: String = ""
            var iconName: String = "folder"
            var sortIndex: Int = 0

            var workspace: Workspace?

            @Relationship(deleteRule: .cascade, inverse: \Folder.space)
            var folders: [Folder]? = []

            init(name: String = "", workspace: Workspace? = nil) {
                self.name = name
                self.workspace = workspace
            }
        }

        /// La forme exacte de `Folder` telle qu'elle existait juste avant cette tache :
        /// `isExpanded` present, aucune trace de `colorIndex`.
        @Model
        final class Folder {
            var id: UUID = UUID()
            var name: String = ""
            var iconName: String = "folder"
            var sortIndex: Int = 0
            var createdAt: Date = Date.now
            var isExpanded: Bool = true

            var space: Space?
            var parent: Folder?

            @Relationship(deleteRule: .cascade, inverse: \Folder.parent)
            var subfolders: [Folder]? = []

            init(
                name: String = "",
                sortIndex: Int = 0,
                isExpanded: Bool = true,
                space: Space? = nil,
                parent: Folder? = nil
            ) {
                self.name = name
                self.sortIndex = sortIndex
                self.isExpanded = isExpanded
                self.space = space
                self.parent = parent
            }
        }
    }

    /// Construit un store sur disque avec la forme "juste avant", contenant un
    /// workspace, une section et un dossier dont `isExpanded` a ete explicitement
    /// mis a `false` (pour verifier qu'il survit intact a cote du nouveau champ),
    /// puis referme completement ce container avant de rendre la main.
    private func makeLegacyStore(at storeURL: URL) throws {
        let schema = Schema([
            LegacyBeforeColorIndex.Workspace.self,
            LegacyBeforeColorIndex.Space.self,
            LegacyBeforeColorIndex.Folder.self
        ])
        let configuration = ModelConfiguration(schema: schema, url: storeURL, cloudKitDatabase: .none)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = ModelContext(container)

        let workspace = LegacyBeforeColorIndex.Workspace(name: "Pro")
        let space = LegacyBeforeColorIndex.Space(name: "Notes", workspace: workspace)
        let folder = LegacyBeforeColorIndex.Folder(name: "Roadmap", sortIndex: 2, isExpanded: false, space: space)

        workspace.spaces = [space]
        space.folders = [folder]

        for item in [workspace, space, folder] as [any PersistentModel] {
            context.insert(item)
        }
        try context.save()
    }

    @Test
    func openingAnOldStoreWithoutColorIndexPreservesDataAndDefaultsColorIndexToNil() throws {
        let storeDirectory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: storeDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: storeDirectory) }
        let storeURL = storeDirectory.appending(path: "Slate.store")

        // --- "Hier" : le store existe avec la forme sans `colorIndex`. ---
        try makeLegacyStore(at: storeURL)

        // --- "Aujourd'hui" : le vrai container de production rouvre ce meme fichier. ---
        let container = try SlateContainer.make(storeURL: storeURL)
        let context = ModelContext(container)

        let folders = try context.fetch(FetchDescriptor<Folder>())
        #expect(folders.count == 1)

        let folder = try #require(folders.first { $0.name == "Roadmap" })
        // Les donnees preexistantes survivent intactes.
        #expect(folder.sortIndex == 2)
        #expect(folder.isExpanded == false)
        // La propriete qui n'existait pas dans l'ancien schema prend bien `nil` pour
        // une ligne deja presente : aucune couleur "devinee".
        #expect(folder.colorIndex == nil)
        #expect(folder.colorToken == nil)

        // Une ecriture reelle post-migration doit fonctionner.
        folder.colorToken = .orange
        try context.save()

        let freshContext = ModelContext(container)
        let refetched = try #require(
            try freshContext.fetch(FetchDescriptor<Folder>()).first { $0.name == "Roadmap" }
        )
        #expect(refetched.colorToken == .orange)
    }
}
