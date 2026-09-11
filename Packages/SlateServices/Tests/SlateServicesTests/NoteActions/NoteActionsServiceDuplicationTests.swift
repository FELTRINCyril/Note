import Foundation
import SlateModel
import SwiftData
import Testing

@testable import SlateServices

/// Tests de Phase 11 (`docs/11_organisation_notes.md`) sur la duplication profonde :
/// le point de rigueur le plus important de cette phase (independance totale entre
/// copie et original, hierarchie de blocs preservee, tous les identifiants
/// regeneres).
@MainActor
struct NoteActionsServiceDuplicationTests {
    private let service = NoteActionsService()

    @Test
    func duplicateCopiesAllBlocksWithPreservedHierarchy() throws {
        let container = try SlateContainer.make(inMemory: true)
        let context = ModelContext(container)
        let note = NoteActionsFixtures.makeRichNote(in: context)

        let copy = service.duplicate(note, in: context, locale: NoteActionsFixtures.frenchLocale)
        try context.save()

        let originalBlocks = NoteActionsFixtures.allBlocks(of: note)
        let copyBlocks = NoteActionsFixtures.allBlocks(of: copy)
        #expect(originalBlocks.count == copyBlocks.count)
        #expect(copyBlocks.map(\.type) == originalBlocks.map(\.type))

        // Hierarchie preservee : la colonne et le tableau se retrouvent avec leurs
        // enfants au bon endroit dans la copie.
        let copyColumnList = try #require(copy.blocks?.first { $0.type == .columnList })
        let copyColumn = try #require(copyColumnList.children?.first { $0.type == .column })
        let copyColumnParagraph = try #require(copyColumn.children?.first)
        #expect(copyColumnParagraph.text?.plainText == "Dans la colonne")
        #expect(copyColumnParagraph.parent?.id == copyColumn.id)

        let copyTable = try #require(copy.blocks?.first { $0.type == .table })
        let copyRow = try #require(copyTable.children?.first { $0.type == .tableRow })
        let copyCell = try #require(copyRow.children?.first { $0.type == .tableCell })
        #expect(copyCell.text?.plainText == "Cellule")
    }

    @Test
    func duplicateRegeneratesAllIdentifiers() throws {
        let container = try SlateContainer.make(inMemory: true)
        let context = ModelContext(container)
        let note = NoteActionsFixtures.makeRichNote(in: context)

        let copy = service.duplicate(note, in: context, locale: NoteActionsFixtures.frenchLocale)
        try context.save()

        #expect(copy.id != note.id)

        let originalIDs = NoteActionsFixtures.allBlockIDs(of: note)
        let copyIDs = NoteActionsFixtures.allBlockIDs(of: copy)
        #expect(originalIDs.isDisjoint(with: copyIDs))
        #expect(originalIDs.count == copyIDs.count)

        let originalAttachmentID = try #require(
            NoteActionsFixtures.allBlocks(of: note).first { $0.type == .image }?.attachment?.id
        )
        let copyAttachmentID = try #require(
            NoteActionsFixtures.allBlocks(of: copy).first { $0.type == .image }?.attachment?.id
        )
        #expect(originalAttachmentID != copyAttachmentID)
    }

    @Test
    func duplicateCopiesAttachmentDataIndependently() throws {
        let container = try SlateContainer.make(inMemory: true)
        let context = ModelContext(container)
        let note = NoteActionsFixtures.makeRichNote(in: context)

        let copy = service.duplicate(note, in: context, locale: NoteActionsFixtures.frenchLocale)
        try context.save()

        let originalAttachment = try #require(
            NoteActionsFixtures.allBlocks(of: note).first { $0.type == .image }?.attachment
        )
        let copyAttachment = try #require(
            NoteActionsFixtures.allBlocks(of: copy).first { $0.type == .image }?.attachment
        )
        #expect(copyAttachment.data == originalAttachment.data)
        #expect(copyAttachment.filename == originalAttachment.filename)
        #expect(copyAttachment.width == originalAttachment.width)
    }

    @Test
    func duplicateSuffixesTitleAccordingToLocale() throws {
        let container = try SlateContainer.make(inMemory: true)
        let context = ModelContext(container)
        let note = Note(title: "Idees")
        context.insert(note)

        let frenchCopy = service.duplicate(note, in: context, locale: NoteActionsFixtures.frenchLocale)
        #expect(frenchCopy.title == "Idees copie")

        let englishCopy = service.duplicate(note, in: context, locale: Locale(identifier: "en_US"))
        #expect(englishCopy.title == "Idees copy")
    }

    @Test
    func duplicateOfUntitledNoteProducesJustTheSuffix() throws {
        let container = try SlateContainer.make(inMemory: true)
        let context = ModelContext(container)
        let note = Note(title: "")
        context.insert(note)

        let copy = service.duplicate(note, in: context, locale: NoteActionsFixtures.frenchLocale)
        #expect(copy.title == "copie")
    }

    /// Le point le plus important de cette phase : modifier la copie ne doit JAMAIS
    /// atteindre l'original, et inversement. Verifie sur le texte d'un bloc, les
    /// octets d'une piece jointe, et l'ajout d'un bloc supplementaire.
    @Test
    func duplicateProducesATotallyIndependentCopy() throws {
        let container = try SlateContainer.make(inMemory: true)
        let context = ModelContext(container)
        let note = NoteActionsFixtures.makeRichNote(in: context)

        let copy = service.duplicate(note, in: context, locale: NoteActionsFixtures.frenchLocale)
        try context.save()

        // 1. Modifier le texte d'un bloc de la copie ne doit pas changer l'original.
        let copyParagraph = try #require(copy.blocks?.first { $0.type == .paragraph })
        copyParagraph.text = RichText(plainText: "Modifie dans la copie")
        let originalParagraph = try #require(note.blocks?.first { $0.type == .paragraph })
        #expect(originalParagraph.text?.plainText == "Paragraphe")

        // 2. Modifier les octets de la piece jointe de la copie ne doit pas changer
        // ceux de l'original.
        let copyAttachment = try #require(
            NoteActionsFixtures.allBlocks(of: copy).first { $0.type == .image }?.attachment
        )
        copyAttachment.data = Data([0x00, 0x01])
        let originalAttachment = try #require(
            NoteActionsFixtures.allBlocks(of: note).first { $0.type == .image }?.attachment
        )
        #expect(originalAttachment.data == Data([0xFF, 0xD8, 0xFF]))

        // 3. Ajouter un bloc a la copie ne doit pas apparaitre dans l'original.
        let extraBlock = Block(order: 99, type: .paragraph, text: RichText(plainText: "Nouveau"), note: copy)
        context.insert(extraBlock)
        copy.blocks?.append(extraBlock)
        try context.save()
        #expect(NoteActionsFixtures.allBlocks(of: copy).count == NoteActionsFixtures.allBlocks(of: note).count + 1)

        // 4. Et inversement : modifier l'original apres la duplication ne doit pas
        // atteindre la copie.
        originalParagraph.text = RichText(plainText: "Modifie dans l'original")
        #expect(copyParagraph.text?.plainText == "Modifie dans la copie")
    }

    @Test
    func duplicateKeepsCopyInSameFolderAndResetsState() throws {
        let container = try SlateContainer.make(inMemory: true)
        let context = ModelContext(container)
        let folder = Folder(name: "Projets")
        context.insert(folder)
        let note = Note(title: "Source", isPinned: true, isFavorite: true, folder: folder)
        context.insert(note)
        try context.save()

        let copy = service.duplicate(note, in: context, locale: NoteActionsFixtures.frenchLocale)

        #expect(copy.folder?.id == folder.id)
        #expect(copy.isPinned == false)
        #expect(copy.isFavorite == false)
        #expect(copy.isTrashed == false)
        #expect(copy.trashedAt == nil)
    }

    /// Regression Phase 12 (revue de securite) : dupliquer une note verrouillee ne
    /// doit JAMAIS produire une copie deverrouillee. Sans quoi le menu contextuel -
    /// qui n'exige aucune authentification pour "Dupliquer" - deviendrait un
    /// contournement complet du verrou : la copie exposerait en clair (extrait,
    /// recherche, ouverture) tout le contenu que l'original protegeait.
    @Test
    func duplicateOfLockedNotePreservesLockAndDerivedTextInvariant() throws {
        let container = try SlateContainer.make(inMemory: true)
        let context = ModelContext(container)
        let note = NoteActionsFixtures.makeRichNote(in: context)
        note.refreshDerivedText()
        try context.save()
        #expect(!note.plainText.isEmpty)

        note.lock()
        #expect(note.plainText.isEmpty)
        #expect(note.snippetText.isEmpty)

        let copy = service.duplicate(note, in: context, locale: NoteActionsFixtures.frenchLocale)
        try context.save()

        #expect(copy.isLocked == true)
        #expect(copy.plainText.isEmpty)
        #expect(copy.snippetText.isEmpty)
    }
}
