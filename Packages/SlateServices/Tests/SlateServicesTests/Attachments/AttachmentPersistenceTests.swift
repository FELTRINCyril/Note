import Foundation
import SlateModel
import SwiftData
import Testing

@testable import SlateServices

/// Tests de Phase 9 : round-trip SwiftData reel d'un `Attachment` avec son binaire, et
/// comportement de la suppression (cascade vs orphelin), meme motif que
/// `EntityGraphTests` cote SlateModel.
@MainActor
struct AttachmentPersistenceTests {
    private let service = AttachmentService()

    /// Construit Note -> Block(image) -> Attachment(avec binaire), insere et sauve.
    private func makeImageBlock(in context: ModelContext, data: Data) throws -> (note: Note, block: Block) {
        let note = Note(title: "Note avec image")
        let block = Block(order: 0, type: .image, note: note)
        let attachment = SlateModel.Attachment(
            filename: "photo.jpg",
            uti: "public.jpeg",
            data: data,
            width: 300,
            height: 300,
            block: block
        )
        block.attachment = attachment
        context.insert(note)
        context.insert(block)
        context.insert(attachment)
        try context.save()
        return (note, block)
    }

    @Test
    func attachmentBinaryRoundTripsIntactThroughAFreshContext() throws {
        let container = try SlateContainer.make(inMemory: true)
        let writingContext = ModelContext(container)

        let originalData = ImageFixtures.jpegData(width: 300, height: 300)
        _ = try makeImageBlock(in: writingContext, data: originalData)

        // Contexte frais : la seule preuve honnete que le binaire externalise a bien
        // ete persiste, pas seulement conserve en memoire par le meme contexte.
        let freshContext = ModelContext(container)
        let fetchedAttachments = try freshContext.fetch(FetchDescriptor<SlateModel.Attachment>())
        #expect(fetchedAttachments.count == 1)
        #expect(fetchedAttachments.first?.data == originalData)
        #expect(fetchedAttachments.first?.width == 300)
        #expect(fetchedAttachments.first?.filename == "photo.jpg")
    }

    @Test
    func deletingBlockCascadesToItsAttachment() throws {
        let container = try SlateContainer.make(inMemory: true)
        let context = ModelContext(container)
        let (_, block) = try makeImageBlock(in: context, data: Data([0x01]))

        context.delete(block)
        try context.save()

        let remaining = try context.fetch(FetchDescriptor<SlateModel.Attachment>())
        #expect(remaining.isEmpty)
    }

    /// Prouve le comportement reel (et le risque) d'une simple deconnexion de
    /// relation, sans passer par le service : contrairement a la suppression du bloc
    /// porteur (qui cascade, voir le test ci-dessus), vider `block.attachment` ne
    /// supprime PAS la ligne `Attachment` du store. Elle devient orpheline. C'est
    /// exactement pour cette raison que `AttachmentService.removeAttachment` existe et
    /// doit toujours etre prefere a une simple affectation `nil`.
    @Test
    func detachingAttachmentWithoutDeletingLeavesItOrphaned() throws {
        let container = try SlateContainer.make(inMemory: true)
        let context = ModelContext(container)
        let (_, block) = try makeImageBlock(in: context, data: Data([0x01]))

        block.attachment = nil
        try context.save()

        let remaining = try context.fetch(FetchDescriptor<SlateModel.Attachment>())
        #expect(remaining.count == 1, "L'attachment detache sans suppression explicite reste orphelin dans le store.")
    }

    @Test
    func removeAttachmentThroughServiceDeletesItProperly() throws {
        let container = try SlateContainer.make(inMemory: true)
        let context = ModelContext(container)
        let (_, block) = try makeImageBlock(in: context, data: Data([0x01]))

        service.removeAttachment(from: block, in: context)
        try context.save()

        #expect(block.attachment == nil)
        let remaining = try context.fetch(FetchDescriptor<SlateModel.Attachment>())
        #expect(remaining.isEmpty)
    }

    @Test
    func replaceAttachmentThroughServiceDeletesOldOne() throws {
        let container = try SlateContainer.make(inMemory: true)
        let context = ModelContext(container)
        let (_, block) = try makeImageBlock(in: context, data: Data([0x01]))

        let replacement = SlateModel.Attachment(filename: "nouvelle.png", uti: "public.png", data: Data([0x02]))
        service.replaceAttachment(of: block, with: replacement, in: context)
        try context.save()

        let remaining = try context.fetch(FetchDescriptor<SlateModel.Attachment>())
        #expect(remaining.count == 1)
        #expect(remaining.first?.filename == "nouvelle.png")
        #expect(block.attachment?.filename == "nouvelle.png")
    }
}
