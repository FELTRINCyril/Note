import Foundation
import SwiftData
import Testing

@testable import SlateModel

/// Tests de Phase 2 (`docs/02_modele_donnees.md`) : construction de la chaine complete
/// du modele conceptuel, relecture, imbrication/ordre des blocs, et suppression en
/// cascade verifiee par un fetch reel (pas seulement par inspection de la relation en
/// memoire).
@MainActor
struct EntityGraphTests {

    /// Regroupe les objets racine de la chaine complete construite par
    /// `makeFullGraph`, pour que chaque test puisse acceder a ce qu'il verifie sans un
    /// tuple a rallonge (`large_tuple` SwiftLint).
    private struct Graph {
        let workspace: Workspace
        let space: Space
        let rootFolder: Folder
        let subFolder: Folder
        let note: Note
        let rootBlocks: [Block]
        let listItemChildren: [Block]
        let attachment: SlateModel.Attachment
    }

    /// Construit une chaine complete Workspace -> Space -> Folder -> sous-Folder ->
    /// Note -> plusieurs Block (dont des blocs imbriques) -> Attachment, l'insere et la
    /// sauvegarde. Retourne le contexte pour que chaque test puisse fetcher ce qu'il
    /// verifie.
    private func makeFullGraph(in context: ModelContext) throws -> Graph {
        let workspace = Workspace(name: "Pro")
        let space = Space(name: "Notes", workspace: workspace)
        let rootFolder = Folder(name: "Projets", space: space)
        let subFolder = Folder(name: "Slate", space: space, parent: rootFolder)

        let note = Note(title: "Modele de donnees", folder: subFolder)

        let heading = Block(order: 0, type: .heading1, text: RichText(plainText: "Titre"), note: note)
        let paragraph = Block(order: 1, type: .paragraph, text: RichText(plainText: "Un paragraphe."), note: note)
        let listRoot = Block(order: 2, type: .bulletedList, text: RichText(plainText: "Liste"), note: note)

        // Deux items imbriques sous `listRoot`, avec leur propre ordre.
        let childOne = Block(
            order: 0,
            type: .bulletedList,
            text: RichText(plainText: "Item 1"),
            note: note,
            parent: listRoot
        )
        let childTwo = Block(
            order: 1,
            type: .bulletedList,
            text: RichText(plainText: "Item 2"),
            note: note,
            parent: listRoot
        )

        let imageBlock = Block(order: 3, type: .image, note: note)
        let attachment = SlateModel.Attachment(
            filename: "photo.jpg",
            uti: "public.jpeg",
            data: Data([0xFF, 0xD8, 0xFF]),
            width: 800,
            height: 600,
            block: imageBlock
        )
        imageBlock.attachment = attachment

        workspace.spaces = [space]
        space.folders = [rootFolder]
        rootFolder.subfolders = [subFolder]
        subFolder.notes = [note]
        note.blocks = [heading, paragraph, listRoot, imageBlock]
        listRoot.children = [childOne, childTwo]

        for item in [
            workspace, space, rootFolder, subFolder, note,
            heading, paragraph, listRoot, childOne, childTwo, imageBlock, attachment
        ] as [any PersistentModel] {
            context.insert(item)
        }
        try context.save()

        return Graph(
            workspace: workspace,
            space: space,
            rootFolder: rootFolder,
            subFolder: subFolder,
            note: note,
            rootBlocks: [heading, paragraph, listRoot, imageBlock],
            listItemChildren: [childOne, childTwo],
            attachment: attachment
        )
    }

    @Test
    func fullChainRoundTripsThroughFetch() throws {
        let container = try SlateContainer.make(inMemory: true)
        let context = ModelContext(container)
        _ = try makeFullGraph(in: context)

        let fetchedWorkspaces = try context.fetch(FetchDescriptor<Workspace>())
        #expect(fetchedWorkspaces.count == 1)
        #expect(fetchedWorkspaces.first?.name == "Pro")

        let fetchedNotes = try context.fetch(FetchDescriptor<Note>())
        #expect(fetchedNotes.count == 1)
        let fetchedNote = try #require(fetchedNotes.first)
        #expect(fetchedNote.title == "Modele de donnees")
        #expect(fetchedNote.folder?.name == "Slate")
        #expect(fetchedNote.folder?.parent?.name == "Projets")

        let fetchedBlocks = try context.fetch(FetchDescriptor<Block>())
        // 4 blocs racine + 2 items de liste imbriques.
        #expect(fetchedBlocks.count == 6)

        let fetchedAttachments = try context.fetch(FetchDescriptor<SlateModel.Attachment>())
        #expect(fetchedAttachments.count == 1)
        #expect(fetchedAttachments.first?.filename == "photo.jpg")
        #expect(fetchedAttachments.first?.width == 800)
    }

    /// Round-trip explicite du texte riche d'un bloc a travers un fetch reel (nouvel
    /// objet materialise par SwiftData, pas l'instance en memoire d'origine). Voir la
    /// documentation de `Block.textData`/`Block.text` : c'est precisement le chemin
    /// qui plantait quand `RichText` etait stocke directement comme propriete
    /// `@Model`.
    @Test
    func blockTextRoundTripsThroughRealFetch() throws {
        let container = try SlateContainer.make(inMemory: true)
        let context = ModelContext(container)
        let note = Note(title: "Texte")
        let block = Block(order: 0, type: .paragraph, text: RichText(plainText: "Contenu riche"), note: note)
        note.blocks = [block]
        context.insert(note)
        context.insert(block)
        try context.save()

        // Un nouveau ModelContext force un fetch reel depuis le store, pas une
        // reutilisation des instances en memoire de ce test.
        let freshContext = ModelContext(container)
        let fetchedBlocks = try freshContext.fetch(FetchDescriptor<Block>())
        let fetchedBlock = try #require(fetchedBlocks.first)

        #expect(fetchedBlock.text?.plainText == "Contenu riche")
    }

    @Test
    func blockNestingAndOrderAreRespected() throws {
        let container = try SlateContainer.make(inMemory: true)
        let context = ModelContext(container)
        let graph = try makeFullGraph(in: context)

        let listRoot = try #require(graph.rootBlocks.first { $0.type == .bulletedList })
        let children = (listRoot.children ?? []).sorted { $0.order < $1.order }
        #expect(children.count == 2)
        #expect(children.map { $0.text?.plainText } == ["Item 1", "Item 2"])
        #expect(children.allSatisfy { $0.parent?.id == listRoot.id })

        let rootOrdered = (graph.note.blocks ?? []).sorted { $0.order < $1.order }
        #expect(rootOrdered.map { $0.type } == [.heading1, .paragraph, .bulletedList, .image])
    }

    @Test
    func deletingNoteCascadesToBlocksAndAttachments() throws {
        let container = try SlateContainer.make(inMemory: true)
        let context = ModelContext(container)
        let graph = try makeFullGraph(in: context)

        let blocksBefore = try context.fetch(FetchDescriptor<Block>())
        #expect(blocksBefore.count == 6)
        let attachmentsBefore = try context.fetch(FetchDescriptor<SlateModel.Attachment>())
        #expect(attachmentsBefore.count == 1)

        context.delete(graph.note)
        try context.save()

        // Verification par fetch reel dans le store, pas par inspection de la relation
        // en memoire : c'est la seule preuve honnete que la cascade a bien supprime les
        // lignes, y compris les blocs imbriques (childOne/childTwo sous listRoot) et la
        // piece jointe du bloc image.
        let blocksAfter = try context.fetch(FetchDescriptor<Block>())
        #expect(blocksAfter.isEmpty)

        let attachmentsAfter = try context.fetch(FetchDescriptor<SlateModel.Attachment>())
        #expect(attachmentsAfter.isEmpty)

        // Le dossier, la section et le workspace survivent : la cascade descend, elle
        // ne remonte pas.
        let foldersAfter = try context.fetch(FetchDescriptor<Folder>())
        #expect(foldersAfter.count == 2)
    }

    @Test
    func deletingFolderCascadesToSubfolderAndNoteButNotToSpace() throws {
        let container = try SlateContainer.make(inMemory: true)
        let context = ModelContext(container)
        let graph = try makeFullGraph(in: context)

        context.delete(graph.rootFolder)
        try context.save()

        let foldersAfter = try context.fetch(FetchDescriptor<Folder>())
        #expect(foldersAfter.isEmpty)

        let notesAfter = try context.fetch(FetchDescriptor<Note>())
        #expect(notesAfter.isEmpty)

        let blocksAfter = try context.fetch(FetchDescriptor<Block>())
        #expect(blocksAfter.isEmpty)

        let spacesAfter = try context.fetch(FetchDescriptor<Space>())
        #expect(spacesAfter.count == 1)
    }

    @Test
    func deletingBlockCascadesToChildrenAndAttachmentOnly() throws {
        let container = try SlateContainer.make(inMemory: true)
        let context = ModelContext(container)
        let graph = try makeFullGraph(in: context)

        let listRoot = try #require(graph.rootBlocks.first { $0.type == .bulletedList })
        context.delete(listRoot)
        try context.save()

        let blocksAfter = try context.fetch(FetchDescriptor<Block>())
        // 6 blocs au depart - listRoot - ses 2 enfants = 3 restants.
        #expect(blocksAfter.count == 3)

        // La piece jointe du bloc image (non touche) doit toujours exister.
        let attachmentsAfter = try context.fetch(FetchDescriptor<SlateModel.Attachment>())
        #expect(attachmentsAfter.count == 1)
    }

    @Test
    func tagSurvivesIndependentlyOfNotesAndFolders() throws {
        let container = try SlateContainer.make(inMemory: true)
        let context = ModelContext(container)
        let graph = try makeFullGraph(in: context)

        let tag = SlateModel.Tag(name: "Important", colorHex: "#FF3B30")
        context.insert(tag)
        try context.save()

        context.delete(graph.note)
        context.delete(graph.rootFolder)
        try context.save()

        let tagsAfter = try context.fetch(FetchDescriptor<SlateModel.Tag>())
        #expect(tagsAfter.count == 1)
        #expect(tagsAfter.first?.name == "Important")
    }
}
