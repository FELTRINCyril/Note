import Foundation
import SlateModel
@testable import SlateServices
import SlateUI
import SwiftData
import Testing

@testable import SlateEditor

/// Blocs media (`BlockType.image`/`.file`, Phase 9, docs/09_medias_pieces_jointes.md) :
/// insertion par le menu "/", suppression/remplacement d'une piece jointe (purge REELLE
/// du `ModelContext`, meme motif que `EditorControllerDeletionPurgeTests`), paliers de
/// largeur/alignement d'une image, legende, et refus d'un dossier depose.
@MainActor
@Suite("EditorController - blocs media")
struct EditorControllerAttachmentsTests {
    private struct Fixture {
        let controller: EditorController
        let note: Note
        let context: ModelContext
    }

    /// Note d'un seul paragraphe, inseree dans un vrai `ModelContext` en memoire --
    /// necessaire pour les tests qui verifient la purge/l'insertion reelle d'un
    /// `Attachment` (voir `EditorControllerDeletionPurgeTests`, meme motif).
    private func makeNote(text: String = "") throws -> Fixture {
        let container = try SlateContainer.make(inMemory: true)
        let context = ModelContext(container)
        let note = Note(title: "Test")
        context.insert(note)
        let block = Block(order: 0, type: .paragraph, text: RichText(plainText: text))
        block.note = note
        context.insert(block)
        note.blocks = [block]
        try context.save()

        let controller = EditorController(note: note, modelContext: context)
        return Fixture(controller: controller, note: note, context: context)
    }

    // MARK: - Insertion par le menu "/"

    @Test("La commande / image insere un bloc image en dessous, jamais en place, puis un paragraphe focalise")
    func slashImageInsertsMediaBlockBelow() throws {
        let fixture = try makeNote(text: "/image")
        let block = try #require(BlockOrdering.topLevelBlocks(of: fixture.note).first)
        fixture.controller.updateSlashMenuState(for: block, plainText: "/", caretOffset: 1)
        fixture.controller.updateSlashMenuState(for: block, plainText: "/image", caretOffset: 6)
        #expect(fixture.controller.slashMenuState?.selectedCommandID == "image")

        fixture.controller.handleSlashMenuReturn(in: block)

        let blocks = BlockOrdering.topLevelBlocks(of: fixture.note)
        #expect(blocks.count == 3)
        #expect(blocks[0].id == block.id)
        #expect(blocks[0].type == .paragraph)
        #expect(blocks[1].type == .image)
        #expect(blocks[1].attachment == nil)
        #expect(blocks[2].type == .paragraph)
        #expect(blocks[2].text?.isEmpty == true)
        #expect(fixture.controller.focusedBlockID == blocks[2].id)
    }

    @Test("La commande / fichier insere un bloc file en dessous, meme si le bloc de depart est VIDE")
    func slashFileInsertsMediaBlockBelowEvenWhenLeftoverIsEmpty() throws {
        let fixture = try makeNote(text: "/fichier")
        let block = try #require(BlockOrdering.topLevelBlocks(of: fixture.note).first)
        fixture.controller.updateSlashMenuState(for: block, plainText: "/", caretOffset: 1)
        fixture.controller.updateSlashMenuState(for: block, plainText: "/fichier", caretOffset: 8)
        #expect(fixture.controller.slashMenuState?.selectedCommandID == "file")

        fixture.controller.handleSlashMenuReturn(in: block)

        let blocks = BlockOrdering.topLevelBlocks(of: fixture.note)
        #expect(blocks.count == 3)
        #expect(blocks[0].id == block.id, "le bloc d'origine, meme vide apres retrait, n'est JAMAIS converti en place")
        #expect(blocks[0].type == .paragraph)
        #expect(blocks[1].type == .file)
        #expect(blocks[2].type == .paragraph)
        #expect(fixture.controller.focusedBlockID == blocks[2].id)
    }

    // MARK: - Suppression : purge reelle du store (LE test qui compte, voir la tache)

    @Test("Supprimer une piece jointe purge vraiment l'Attachment du store, pas seulement la relation")
    func removeAttachmentPurgesAttachmentFromContext() throws {
        let fixture = try makeNote()
        let block = try #require(BlockOrdering.topLevelBlocks(of: fixture.note).first)
        block.type = .image
        let attachment = SlateModel.Attachment(
            filename: "photo.png", uti: "public.png", data: Data([0x01]), width: 10, height: 10
        )
        attachment.block = block
        block.attachment = attachment
        fixture.context.insert(attachment)
        try fixture.context.save()
        let attachmentID = attachment.id

        fixture.controller.removeAttachment(from: block)
        try fixture.context.save()

        #expect(block.attachment == nil)
        let remaining = try fixture.context.fetch(FetchDescriptor<SlateModel.Attachment>())
        #expect(remaining.isEmpty, "l'Attachment ne doit pas rester orphelin dans le store")
        #expect(!remaining.contains { $0.id == attachmentID })
    }

    @Test("Supprimer le bloc image entier purge aussi son Attachment (cascade)")
    func deletingImageBlockPurgesItsAttachment() throws {
        let fixture = try makeNote()
        let block = try #require(BlockOrdering.topLevelBlocks(of: fixture.note).first)
        block.type = .image
        let attachment = SlateModel.Attachment(filename: "photo.png", uti: "public.png", data: Data([0x01]))
        attachment.block = block
        block.attachment = attachment
        fixture.context.insert(attachment)
        // Un deuxieme bloc pour que la note reste editable apres suppression.
        let other = Block(order: 1, type: .paragraph, text: RichText())
        other.note = fixture.note
        fixture.context.insert(other)
        fixture.note.blocks = [block, other]
        try fixture.context.save()

        fixture.controller.deleteBlock(block)
        try fixture.context.save()

        let remainingAttachments = try fixture.context.fetch(FetchDescriptor<SlateModel.Attachment>())
        #expect(remainingAttachments.isEmpty)
    }

    // MARK: - Remplacement : l'ancienne piece jointe ne reste pas orpheline

    @Test("Remplacer une image purge l'ancienne piece jointe, seule la nouvelle survit")
    func applyImportedImageReplacesWithoutLeavingOrphan() throws {
        let fixture = try makeNote()
        let block = try #require(BlockOrdering.topLevelBlocks(of: fixture.note).first)
        block.type = .image
        let original = SlateModel.Attachment(filename: "old.png", uti: "public.png", data: Data([0x01]))
        original.block = block
        block.attachment = original
        fixture.context.insert(original)
        try fixture.context.save()
        let originalID = original.id

        let replacement = ImportedImage(
            filename: "new.png", uti: "public.png", data: Data([0x02, 0x03]),
            width: 20, height: 20, originalByteCount: 2, wasResized: false
        )
        fixture.controller.applyImportedImage(replacement, into: block)
        try fixture.context.save()

        #expect(block.attachment?.filename == "new.png")
        let remaining = try fixture.context.fetch(FetchDescriptor<SlateModel.Attachment>())
        #expect(remaining.count == 1)
        #expect(!remaining.contains { $0.id == originalID })
    }

    @Test("Un import qui revient APRES la suppression de son bloc ne ressuscite ni Attachment ni entree d'echec")
    func applyImportedImageIgnoresABlockDeletedWhileImporting() throws {
        let fixture = try makeNote()
        let block = try #require(BlockOrdering.topLevelBlocks(of: fixture.note).first)
        block.type = .image
        // Un deuxieme bloc pour que la note reste editable apres suppression.
        let other = Block(order: 1, type: .paragraph, text: RichText())
        other.note = fixture.note
        fixture.context.insert(other)
        fixture.note.blocks = [block, other]
        try fixture.context.save()

        // Simule la fenetre entre le lancement d'un import (`Task.detached`,
        // `ImageBlockContentView.importImage(at:)`) et son retour : l'utilisateur
        // supprime le bloc pendant que l'import decode encore hors acteur principal.
        fixture.controller.deleteBlock(block)
        // `deleteBlock(_:)` sauvegarde deja de lui-meme (`persistStructuralChange()`) :
        // apres cette sauvegarde, `block.isDeleted` redevient `false` (verifie
        // empiriquement), seul `modelContext == nil` reste un signal fiable -- voir le
        // commentaire de `applyImportedImage(_:into:)`.
        #expect(block.modelContext == nil)

        let imported = ImportedImage(
            filename: "trop-tard.png", uti: "public.png", data: Data([0x01]),
            width: 10, height: 10, originalByteCount: 1, wasResized: false
        )
        fixture.controller.applyImportedImage(imported, into: block)
        fixture.controller.recordAttachmentImportFailure(
            AttachmentImportError.unreadableFile(name: "trop-tard.png"), for: block
        )

        #expect(fixture.controller.attachmentImportFailures[block.id] == nil)
        let remaining = try fixture.context.fetch(FetchDescriptor<SlateModel.Attachment>())
        #expect(remaining.isEmpty, "un import tardif ne doit pas creer d'Attachment sur un bloc deja supprime")
    }

    // MARK: - Palier de largeur/alignement (Opt+Left/Opt+Right)

    @Test("cycleImageAlignment avance/recule d'un palier, borne aux deux extremites (pas de bouclage)")
    func cycleImageAlignmentClampsAtBounds() throws {
        let fixture = try makeNote()
        let block = try #require(BlockOrdering.topLevelBlocks(of: fixture.note).first)
        block.type = .image
        #expect(block.attributes.imageAlignment == nil)

        // Depuis nil (repli .left) : reculer reste sur .left, borne basse.
        let stayedAtLeft = fixture.controller.cycleImageAlignment(forward: false, in: block)
        #expect(stayedAtLeft == .left)
        #expect(block.attributes.imageAlignment == SlateImageAlignment.left.rawValue)

        #expect(fixture.controller.cycleImageAlignment(forward: true, in: block) == .center)
        #expect(fixture.controller.cycleImageAlignment(forward: true, in: block) == .right)
        #expect(fixture.controller.cycleImageAlignment(forward: true, in: block) == .overflow)

        // Borne haute : le cycle s'arrete au DERNIER palier propose (les 5 paliers du
        // design sont desormais tous offerts, Phase 10 -- voir
        // `EditorController.availableImageAlignments`).
        #expect(fixture.controller.cycleImageAlignment(forward: true, in: block) == .fullWidth)
        let stayedAtFullWidth = fixture.controller.cycleImageAlignment(forward: true, in: block)
        #expect(stayedAtFullWidth == .fullWidth)
        #expect(block.attributes.imageAlignment == SlateImageAlignment.fullWidth.rawValue)
    }

    /// Le clavier et la barre d'alignement doivent proposer EXACTEMENT le meme jeu de
    /// paliers : deux listes divergentes donneraient un palier atteignable au clavier
    /// mais absent de la barre (ou l'inverse), sans aucune erreur.
    @Test("Le cycle clavier n'atteint que les paliers reellement proposes")
    func cycleReachesOnlyOfferedAlignments() throws {
        let fixture = try makeNote()
        let block = try #require(BlockOrdering.topLevelBlocks(of: fixture.note).first)
        block.type = .image
        let offered = Set(EditorController.availableImageAlignments)

        // 10 pas en avant : largement de quoi depasser la liste, quelle que soit sa
        // taille. Aucun palier non propose ne doit apparaitre en chemin.
        for _ in 0..<10 {
            let reached = try #require(fixture.controller.cycleImageAlignment(forward: true, in: block))
            #expect(offered.contains(reached))
        }
        for _ in 0..<10 {
            let reached = try #require(fixture.controller.cycleImageAlignment(forward: false, in: block))
            #expect(offered.contains(reached))
        }
        // Les 5 paliers du design sont tous proposes depuis la Phase 10.
        #expect(offered == Set(SlateImageAlignment.allCases))
    }

    @Test("cycleImageAlignment est sans effet sur un bloc qui n'est pas une image")
    func cycleImageAlignmentNoOpOnNonImageBlock() throws {
        let fixture = try makeNote()
        let block = try #require(BlockOrdering.topLevelBlocks(of: fixture.note).first)
        #expect(block.type == .paragraph)

        let result = fixture.controller.cycleImageAlignment(forward: true, in: block)

        #expect(result == nil)
        #expect(block.attributes.imageAlignment == nil)
    }

    // MARK: - Persistance legende / palier (aller-retour via BlockAttributes)

    @Test("La legende et le palier survivent a un aller-retour via BlockAttributes (encode/decode)")
    func captionAndAlignmentRoundTripThroughBlockAttributes() throws {
        let fixture = try makeNote()
        let block = try #require(BlockOrdering.topLevelBlocks(of: fixture.note).first)
        block.type = .image

        fixture.controller.setImageAlignment(.overflow, in: block)
        fixture.controller.setImageCaption("Architecture des blocs.", in: block)

        let encoded = try JSONEncoder().encode(block.attributes)
        let decoded = try JSONDecoder().decode(BlockAttributes.self, from: encoded)

        #expect(decoded.imageAlignment == SlateImageAlignment.overflow.rawValue)
        #expect(decoded.imageWidth == Double(SlateGeometry.mediaOverflowWidth))
        #expect(decoded.imageCaption == "Architecture des blocs.")
    }

    @Test("Une legende vide efface imageCaption (nil), pas une chaine vide")
    func emptyCaptionClearsAttribute() throws {
        let fixture = try makeNote()
        let block = try #require(BlockOrdering.topLevelBlocks(of: fixture.note).first)
        block.type = .image
        fixture.controller.setImageCaption("Une legende.", in: block)
        #expect(block.attributes.imageCaption != nil)

        fixture.controller.setImageCaption("", in: block)

        #expect(block.attributes.imageCaption == nil)
    }

    // MARK: - Refus d'un dossier depose (AttachmentImportError.isDirectory)

    @Test("Deposer un dossier sur un bloc image est refuse, avec la cause remontee dans attachmentImportFailures")
    func droppingAFolderOnImageBlockIsRejectedWithCause() throws {
        let fixture = try makeNote()
        let block = try #require(BlockOrdering.topLevelBlocks(of: fixture.note).first)
        block.type = .image
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("SlateAttachmentDropTest-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directoryURL) }

        fixture.controller.importImageFile(at: directoryURL, into: block)

        #expect(block.attachment == nil)
        let failure = fixture.controller.attachmentImportFailures[block.id]
        #expect(failure != nil)
        #expect(failure?.contains(directoryURL.lastPathComponent) == true)
    }

    @Test("Deposer un dossier sur un bloc fichier est refuse, avec la cause remontee")
    func droppingAFolderOnFileBlockIsRejectedWithCause() throws {
        let fixture = try makeNote()
        let block = try #require(BlockOrdering.topLevelBlocks(of: fixture.note).first)
        block.type = .file
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("SlateAttachmentDropTest-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directoryURL) }

        fixture.controller.importAttachedFile(at: directoryURL, into: block)

        #expect(block.attachment == nil)
        let failure = fixture.controller.attachmentImportFailures[block.id]
        #expect(failure != nil)
    }
}
