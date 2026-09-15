import Foundation
import SwiftData
import Testing

@testable import SlateModel

/// Preuve empirique du bug reel decouvert sur la machine de Cyril (voir
/// `docs/DEV_ENV.md`, piege n°2 bis, et `BlockAttributes.isHeaderRow`) et
/// garde-fou contre sa reapparition.
///
/// ## Le bug
///
/// `BlockAttributes` est stockee **directement** comme propriete `@Model` de `Block`
/// (pas encapsulee en `Data`, contrairement a `RichText`/`textData`, voir la
/// documentation de tete de `Block.swift`) : SwiftData l'aplatit donc en autant de
/// colonnes Core Data distinctes que de champs de la struct ("composite coder"). Un
/// champ `Bool` non-optionnel ajoute a une telle struct *apres* la mise en circulation
/// d'un store existant devient un attribut obligatoire sans valeur pour toute ligne
/// deja presente, et fait echouer l'ouverture de ce store a la migration legere
/// (`NSCocoaErrorDomain` 134110). C'est exactement ce qui est arrive avec
/// `isHeaderRow` (Phase 8, tableaux) : aucun test existant ne l'a attrape parce que
/// **tous** les tests de ce package utilisaient jusqu'ici un container en memoire -
/// donc toujours un store neuf, jamais une migration reelle sur un fichier existant.
///
/// ## Comment "l'ancien schema" est simule
///
/// Meme technique que `FolderExpandedStateMigrationTests`/`FolderColorIndexMigrationTests` :
/// un espace de noms prive `LegacyBeforeHeaderRow` reproduit la forme exacte de
/// `Workspace`/`Space`/`Folder`/`Note`/`Block` telle qu'elle existait juste avant
/// l'ajout de `isHeaderRow` a `BlockAttributes` (donc avec un `LegacyBlockAttributes`
/// qui n'a pas du tout ce champ - ni present, ni optionnel : purement absent, comme sur
/// le store reel de Cyril, qui ne contient meme pas la colonne `ZISHEADERROW`). Les
/// types prives portent les memes noms courts pour que SwiftData les fasse
/// correspondre aux memes tables SQLite que le vrai `SlateModel`.
///
/// Ce test ouvre ensuite ce store avec le **vrai** `SlateContainer` de production et
/// verifie que les donnees existantes (y compris un bloc `table`/`tableRow` avec ses
/// propres attributs) survivent, que `isHeaderRow` reste `nil` (pas de valeur devinee)
/// pour les lignes deja presentes, et qu'une ecriture reelle post-migration fonctionne.
@MainActor
struct BlockAttributesHeaderRowMigrationTests {

    /// Reproduction figee, a but de test uniquement, de la forme de `BlockAttributes`
    /// juste avant l'ajout de `isHeaderRow` : tous les champs adjacents sont presents
    /// (pour verifier qu'ils survivent intacts), mais `isHeaderRow` n'existe pas du
    /// tout, comme sur le store reel de Cyril.
    fileprivate struct LegacyBlockAttributes: Codable, Hashable, Sendable {
        var language: String?
        var headingLevel: Int?
        var isChecked: Bool = false
        var calloutIcon: String?
        var imageWidth: Double?
        var imageHeight: Double?
        var imageAltText: String?
        var columnWidthRatio: Double?
        var columnCount: Int?
        var linkedNoteID: UUID?
        var sourceURLString: String?
    }

    /// Reproduction figee, a but de test uniquement, de la forme de
    /// `Workspace`/`Space`/`Folder`/`Note`/`Block` telle qu'elle existait juste avant
    /// l'ajout de `isHeaderRow`. Ne doit jamais etre alignee sur les evolutions futures
    /// du vrai modele : c'est une photographie du passe.
    fileprivate enum LegacyBeforeHeaderRow {
        @Model
        final class Workspace {
            var id: UUID = UUID()
            var name: String = ""

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

            var workspace: Workspace?

            @Relationship(deleteRule: .cascade, inverse: \Folder.space)
            var folders: [Folder]? = []

            init(name: String = "", workspace: Workspace? = nil) {
                self.name = name
                self.workspace = workspace
            }
        }

        @Model
        final class Folder {
            var id: UUID = UUID()
            var name: String = ""

            var space: Space?

            @Relationship(deleteRule: .cascade, inverse: \Note.folder)
            var notes: [Note]? = []

            init(name: String = "", space: Space? = nil) {
                self.name = name
                self.space = space
            }
        }

        @Model
        final class Note {
            var id: UUID = UUID()
            var title: String = ""

            var folder: Folder?

            @Relationship(deleteRule: .cascade, inverse: \Block.note)
            var blocks: [Block]? = []

            init(title: String = "", folder: Folder? = nil) {
                self.title = title
                self.folder = folder
            }
        }

        /// La forme exacte de `Block` telle qu'elle existait juste avant cette tache :
        /// `attributes` porte `LegacyBlockAttributes`, sans aucune trace d'`isHeaderRow`.
        @Model
        final class Block {
            var id: UUID = UUID()
            var order: Int = 0
            var type: BlockType = BlockType.paragraph
            var attributes: LegacyBlockAttributes = LegacyBlockAttributes()

            var note: Note?
            var parent: Block?

            @Relationship(deleteRule: .cascade, inverse: \Block.parent)
            var children: [Block]? = []

            init(
                order: Int = 0,
                type: BlockType = .paragraph,
                attributes: LegacyBlockAttributes = LegacyBlockAttributes(),
                note: Note? = nil,
                parent: Block? = nil
            ) {
                self.order = order
                self.type = type
                self.attributes = attributes
                self.note = note
                self.parent = parent
            }
        }
    }

    /// Construit un store sur disque avec l'ancienne forme du schema : une note
    /// contenant un `table` racine, avec deux `tableRow` (dont une avec des attributs
    /// deja renseignes cote colonnes existantes, pour verifier qu'ils survivent), puis
    /// referme completement ce container avant de rendre la main.
    private func makeLegacyStore(at storeURL: URL) throws {
        let schema = Schema([
            LegacyBeforeHeaderRow.Workspace.self,
            LegacyBeforeHeaderRow.Space.self,
            LegacyBeforeHeaderRow.Folder.self,
            LegacyBeforeHeaderRow.Note.self,
            LegacyBeforeHeaderRow.Block.self
        ])
        let configuration = ModelConfiguration(schema: schema, url: storeURL, cloudKitDatabase: .none)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = ModelContext(container)

        let workspace = LegacyBeforeHeaderRow.Workspace(name: "Perso")
        let space = LegacyBeforeHeaderRow.Space(name: "Notes", workspace: workspace)
        let folder = LegacyBeforeHeaderRow.Folder(name: "Racine", space: space)
        let note = LegacyBeforeHeaderRow.Note(title: "Tableau de test", folder: folder)

        let table = LegacyBeforeHeaderRow.Block(order: 0, type: .table, note: note)
        let headerRow = LegacyBeforeHeaderRow.Block(
            order: 0,
            type: .tableRow,
            attributes: LegacyBlockAttributes(columnCount: 2),
            note: note,
            parent: table
        )
        let bodyRow = LegacyBeforeHeaderRow.Block(order: 1, type: .tableRow, note: note, parent: table)

        workspace.spaces = [space]
        space.folders = [folder]
        folder.notes = [note]
        note.blocks = [table]
        table.children = [headerRow, bodyRow]

        for item in [workspace, space, folder, note, table, headerRow, bodyRow] as [any PersistentModel] {
            context.insert(item)
        }
        try context.save()
    }

    @Test
    func openingAnOldStoreWithoutHeaderRowPreservesDataAndDefaultsIsHeaderRowToFalse() throws {
        let storeDirectory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: storeDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: storeDirectory) }
        let storeURL = storeDirectory.appending(path: "Slate.store")

        // --- "Hier" : le store existe avec la forme sans `isHeaderRow`. ---
        try makeLegacyStore(at: storeURL)

        // --- "Aujourd'hui" : le vrai container de production rouvre ce meme fichier. ---
        // Avant le correctif de `BlockAttributes.isHeaderRow`, cette ligne seule
        // levait `SwiftDataError` (NSCocoaErrorDomain 134110) : c'est le bug reproduit.
        let container = try SlateContainer.make(storeURL: storeURL)
        let context = ModelContext(container)

        let notes = try context.fetch(FetchDescriptor<Note>())
        #expect(notes.count == 1)
        #expect(notes.first?.title == "Tableau de test")

        let blocks = try context.fetch(FetchDescriptor<Block>())
        #expect(blocks.count == 3)

        let table = try #require(blocks.first { $0.type == .table })
        let rows = (table.children ?? []).sorted { $0.order < $1.order }
        #expect(rows.count == 2)

        // Les donnees preexistantes (colonnes deja presentes avant cette tache)
        // survivent intactes.
        #expect(rows[0].attributes.columnCount == 2)
        #expect(rows[1].attributes.columnCount == nil)

        // Le champ qui n'existait pas du tout dans l'ancien schema est reellement `nil`
        // (pas `false` "devine") pour une ligne deja presente : voir la documentation
        // de `BlockAttributes.isHeaderRow` sur la distinction deliberee entre `nil` et
        // `false`. Cote lecture, l'appelant applique `?? false` (voir
        // `TableBlockContentView`) : aucune ligne d'en-tete "devinee" a l'affichage.
        #expect(rows[0].attributes.isHeaderRow == nil)
        #expect(rows[1].attributes.isHeaderRow == nil)
        #expect((rows[0].attributes.isHeaderRow ?? false) == false)
        #expect((rows[1].attributes.isHeaderRow ?? false) == false)

        // Une ecriture reelle post-migration doit fonctionner (le store n'est pas
        // "en lecture seule degradee" apres l'ajout de colonne).
        rows[0].attributes.isHeaderRow = true
        try context.save()

        let freshContext = ModelContext(container)
        let refetchedTable = try #require(
            try freshContext.fetch(FetchDescriptor<Block>()).first { $0.type == .table }
        )
        let refetchedRows = (refetchedTable.children ?? []).sorted { $0.order < $1.order }
        #expect(refetchedRows[0].attributes.isHeaderRow == true)
        #expect(refetchedRows[1].attributes.isHeaderRow == nil)
    }
}
