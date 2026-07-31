import Foundation
import SwiftData
import Testing

@testable import SlateModel

/// Preuve empirique de la decision de migration documentee dans `SlateSchema.swift`
/// (ajout de `Folder.isExpanded`, sans bump de version) : ce test ouvre, avec le
/// **vrai** `SlateContainer` de production (celui que l'app utilise reellement),
/// un store construit prealablement avec l'ancienne forme de `Folder` - sans
/// `isExpanded` - pour simuler fidelement le store deja present sur la machine de
/// Cyril avant cette tache.
///
/// ## Comment "l'ancien schema" est simule
///
/// Ce test ne peut pas compiler deux versions differentes de `SlateModel` a la fois :
/// il construit donc, uniquement pour son propre usage, un petit schema prive
/// reproduisant la forme exacte de `Workspace`/`Space`/`Folder` **avant** l'ajout de
/// `isExpanded` (voir `LegacyBeforeIsExpanded` ci-dessous). `Note`/`Block`/
/// `Attachment`/`Tag` n'ont pas change dans cette tache et ne sont donc pas dupliques
/// ici : ils ne font pas partie de ce qui doit etre prouve.
///
/// Point technique qui rend cette simulation fidele et pas artificielle : les types
/// prives sont nommes exactement `Workspace`/`Space`/`Folder`, mais nichés dans
/// l'espace de noms `LegacyBeforeIsExpanded` pour ne pas entrer en conflit avec les
/// types de production. `Schema`/SwiftData derive le nom d'entite (et donc le nom de
/// table SQLite) du nom court du type Swift, pas de son nom qualifie - donc
/// `LegacyBeforeIsExpanded.Folder` produit bien une table nommee "Folder", la meme que
/// celle utilisee par le vrai `SlateModel.Folder`. C'est exactement la technique
/// qu'Apple utilise pour ses propres `VersionedSchema` a plusieurs versions (des types
/// `SchemaV1.Trip` / `SchemaV2.Trip` nommes `Trip` dans chaque espace de noms).
///
/// Si cette hypothese s'averait fausse a l'execution (table non retrouvee, erreur de
/// chargement du store), ce test echouerait de facon flagrante - il ne peut pas
/// "reussir a tort".
@MainActor
struct FolderExpandedStateMigrationTests {

    /// Reproduction figee, a but de test uniquement, de la forme de
    /// `Workspace`/`Space`/`Folder` avant l'ajout de `Folder.isExpanded`. Ne doit
    /// jamais etre alignee sur les evolutions futures du vrai modele : c'est une
    /// photographie du passe.
    fileprivate enum LegacyBeforeIsExpanded {
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

        /// La forme exacte de `Folder` telle qu'elle existait avant cette tache :
        /// aucune trace de `isExpanded`.
        @Model
        final class Folder {
            var id: UUID = UUID()
            var name: String = ""
            var iconName: String = "folder"
            var sortIndex: Int = 0
            var createdAt: Date = Date.now

            var space: Space?
            var parent: Folder?

            @Relationship(deleteRule: .cascade, inverse: \Folder.parent)
            var subfolders: [Folder]? = []

            init(name: String = "", sortIndex: Int = 0, space: Space? = nil, parent: Folder? = nil) {
                self.name = name
                self.sortIndex = sortIndex
                self.space = space
                self.parent = parent
            }
        }
    }

    /// Construit un store sur disque avec l'ancienne forme du schema, contenant un
    /// workspace, une section et deux dossiers freres (dont un avec un sous-dossier),
    /// puis referme completement ce container avant de rendre la main - pour que la
    /// suite du test ne puisse repartir que du fichier sur disque, pas d'instances en
    /// memoire.
    private func makeLegacyStore(at storeURL: URL) throws {
        let schema = Schema([
            LegacyBeforeIsExpanded.Workspace.self,
            LegacyBeforeIsExpanded.Space.self,
            LegacyBeforeIsExpanded.Folder.self
        ])
        let configuration = ModelConfiguration(schema: schema, url: storeURL, cloudKitDatabase: .none)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = ModelContext(container)

        let workspace = LegacyBeforeIsExpanded.Workspace(name: "Pro")
        let space = LegacyBeforeIsExpanded.Space(name: "Notes", workspace: workspace)
        let rootFolder = LegacyBeforeIsExpanded.Folder(name: "Projets", sortIndex: 3, space: space)
        let siblingFolder = LegacyBeforeIsExpanded.Folder(name: "Archives", sortIndex: 1, space: space)
        let subFolder = LegacyBeforeIsExpanded.Folder(name: "Slate", sortIndex: 0, space: space, parent: rootFolder)

        workspace.spaces = [space]
        space.folders = [rootFolder, siblingFolder]
        rootFolder.subfolders = [subFolder]

        for item in [workspace, space, rootFolder, siblingFolder, subFolder] as [any PersistentModel] {
            context.insert(item)
        }
        try context.save()
    }

    @Test
    func openingAnOldStoreWithTheCurrentSchemaPreservesDataAndDefaultsIsExpandedToTrue() throws {
        let storeDirectory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: storeDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: storeDirectory) }
        let storeURL = storeDirectory.appending(path: "Slate.store")

        // --- "Hier" : le store existe avec l'ancienne forme de Folder. ---
        try makeLegacyStore(at: storeURL)

        // --- "Aujourd'hui" : le vrai container de production rouvre ce meme fichier. ---
        let container = try SlateContainer.make(storeURL: storeURL)
        let context = ModelContext(container)

        let workspaces = try context.fetch(FetchDescriptor<Workspace>())
        #expect(workspaces.count == 1)
        #expect(workspaces.first?.name == "Pro")

        let folders = try context.fetch(FetchDescriptor<Folder>())
        #expect(folders.count == 3)

        let rootFolder = try #require(folders.first { $0.name == "Projets" })
        #expect(rootFolder.sortIndex == 3)
        // La propriete qui n'existait pas dans l'ancien schema prend bien sa valeur
        // par defaut pour une ligne qui preexistait a son ajout.
        #expect(rootFolder.isExpanded == true)

        let subFolder = try #require(folders.first { $0.name == "Slate" })
        #expect(subFolder.parent?.name == "Projets")
        #expect(subFolder.isExpanded == true)

        let siblingFolder = try #require(folders.first { $0.name == "Archives" })
        #expect(siblingFolder.sortIndex == 1)
        #expect(siblingFolder.isExpanded == true)

        // Une ecriture reelle post-migration doit fonctionner (le store n'est pas
        // "en lecture seule degradee" apres l'ajout de colonne).
        rootFolder.isExpanded = false
        try context.save()

        let freshContext = ModelContext(container)
        let reFetchedRoot = try #require(
            try freshContext.fetch(FetchDescriptor<Folder>()).first { $0.name == "Projets" }
        )
        #expect(reFetchedRoot.isExpanded == false)
    }
}
