import CoreGraphics
import Foundation
import SlateModel
import SwiftData
import Testing
import UniformTypeIdentifiers

@testable import SlateEditor

/// `EditorController+DragDrop.swift` : reordonnancement de bloc(s) par depot resolu via
/// `BlockDropResolution`, creation/extension de colonne par depot lateral, et surtout
/// l'integrite `order`/`parent` a travers une entree/sortie de colonne -- le point de
/// vigilance n°1 de docs/10_dragdrop_colonnes.md. Chaque test pilote directement
/// `performBlockDrop(pointerLocation:)` apres avoir pousse des cadres de bloc factices
/// dans `EditorController.blockFrames` (`updateBlockFrames(_:)`), exactement les memes
/// coordonnees que `NoteDocumentView.blockListCoordinateSpace` en conditions reelles --
/// aucune fenetre necessaire pour cette logique, voir le rapport de fin de tache pour ce
/// qui reste, lui, non verifiable sans fenetre (le geste visuel complet).
@MainActor
@Suite("EditorController - glisser-depose de blocs (Phase 10)")
struct EditorControllerDragDropTests {
    /// Cadres verticalement empiles, un par bloc, dans l'ORDRE fourni. Largeur commune
    /// 600 (tiers lateral = 200 pt) -- assez large pour ne jamais confondre par erreur
    /// un point cense tomber au milieu avec le tiers lateral dans ces tests.
    private func stackedFrames(for blocks: [Block], height: CGFloat = 40) -> [UUID: CGRect] {
        var frames: [UUID: CGRect] = [:]
        for (index, block) in blocks.enumerated() {
            frames[block.id] = CGRect(x: 0, y: CGFloat(index) * height, width: 600, height: height)
        }
        return frames
    }

    // MARK: - Reordonnancement simple (haut/bas)

    @Test("Deposer sur la moitie BASSE du premier bloc reordonne apres lui")
    func dropOnBottomHalfReordersAfter() {
        let note = Note(title: "Test")
        let first = Block(order: 0, type: .paragraph, text: RichText(plainText: "Un"), note: note)
        let second = Block(order: 1, type: .paragraph, text: RichText(plainText: "Deux"), note: note)
        let third = Block(order: 2, type: .paragraph, text: RichText(plainText: "Trois"), note: note)
        note.blocks = [first, second, third]
        let controller = EditorController(note: note)
        controller.updateBlockFrames(stackedFrames(for: [first, second, third]))
        controller.beginBlockDrag(third)

        // Moitie basse du premier bloc (y = 35, bloc [0,40)) : Trois doit se retrouver
        // juste apres Un.
        let result = controller.performBlockDrop(pointerLocation: CGPoint(x: 300, y: 35))

        #expect(result)
        let blocks = BlockOrdering.topLevelBlocks(of: note)
        #expect(blocks.map { $0.text?.plainText } == ["Un", "Trois", "Deux"])
        #expect(blocks.map(\.order) == [0, 1, 2])
    }

    @Test("Deposer sur la moitie HAUTE d'un bloc reordonne avant lui")
    func dropOnTopHalfReordersBefore() {
        let note = Note(title: "Test")
        let first = Block(order: 0, type: .paragraph, text: RichText(plainText: "Un"), note: note)
        let second = Block(order: 1, type: .paragraph, text: RichText(plainText: "Deux"), note: note)
        let third = Block(order: 2, type: .paragraph, text: RichText(plainText: "Trois"), note: note)
        note.blocks = [first, second, third]
        let controller = EditorController(note: note)
        controller.updateBlockFrames(stackedFrames(for: [first, second, third]))
        controller.beginBlockDrag(first)

        // Moitie haute du dernier bloc (y = 85, bloc [80,120)).
        let result = controller.performBlockDrop(pointerLocation: CGPoint(x: 300, y: 85))

        #expect(result)
        let blocks = BlockOrdering.topLevelBlocks(of: note)
        #expect(blocks.map { $0.text?.plainText } == ["Deux", "Un", "Trois"])
    }

    @Test("performBlockDrop echoue sans effet si la cible est le bloc deplace lui-meme")
    func dropOntoSelfIsRejected() {
        let note = Note(title: "Test")
        let first = Block(order: 0, type: .paragraph, note: note)
        let second = Block(order: 1, type: .paragraph, note: note)
        note.blocks = [first, second]
        let controller = EditorController(note: note)
        controller.updateBlockFrames(stackedFrames(for: [first, second]))
        controller.beginBlockDrag(first)

        let result = controller.performBlockDrop(pointerLocation: CGPoint(x: 300, y: 10))

        #expect(!result)
        #expect(BlockOrdering.topLevelBlocks(of: note).map(\.order) == [0, 1])
    }

    @Test("performBlockDrop refuse de deposer un bloc dans son PROPRE sous-arbre (cycle)")
    func dropIntoOwnDescendantIsRejected() {
        let note = Note(title: "Test")
        let parent = Block(order: 0, type: .bulletedList, text: RichText(plainText: "Parent"), note: note)
        let child = Block(
            order: 0, type: .bulletedList, text: RichText(plainText: "Enfant"), note: note, parent: parent
        )
        parent.children = [child]
        note.blocks = [parent, child]
        let controller = EditorController(note: note)
        controller.updateBlockFrames(stackedFrames(for: [parent, child]))
        controller.beginBlockDrag(parent)

        // Cible = son propre enfant (deuxieme cadre).
        let result = controller.performBlockDrop(pointerLocation: CGPoint(x: 300, y: 50))

        #expect(!result)
        #expect(parent.parent == nil)
    }

    // MARK: - Deplacement multi-blocs (plage selectionnee)

    @Test("Le depot d'une plage selectionnee deplace TOUS ses blocs, dans l'ordre")
    func dropWithMultiBlockSelectionMovesEntireRange() {
        let note = Note(title: "Test")
        let first = Block(order: 0, type: .paragraph, text: RichText(plainText: "Un"), note: note)
        let second = Block(order: 1, type: .paragraph, text: RichText(plainText: "Deux"), note: note)
        let third = Block(order: 2, type: .paragraph, text: RichText(plainText: "Trois"), note: note)
        let fourth = Block(order: 3, type: .paragraph, text: RichText(plainText: "Quatre"), note: note)
        note.blocks = [first, second, third, fourth]
        let controller = EditorController(note: note)
        controller.updateBlockFrames(stackedFrames(for: [first, second, third, fourth]))
        controller.selectBlock(second)
        controller.extendSelection(to: third)
        controller.beginBlockDrag(second)

        // Moitie basse du dernier bloc (y = 150, bloc [120,160), midpoint 140).
        let result = controller.performBlockDrop(pointerLocation: CGPoint(x: 300, y: 150))

        #expect(result)
        let blocks = BlockOrdering.topLevelBlocks(of: note)
        #expect(blocks.map { $0.text?.plainText } == ["Un", "Quatre", "Deux", "Trois"])
    }

    // MARK: - Depot lateral -> creation de colonne (artboard I)

    @Test("Deposer sur le tiers DROIT cree une colonne, target a gauche")
    func dropOnRightThirdCreatesColumnsWithTargetFirst() {
        let note = Note(title: "Test")
        let first = Block(order: 0, type: .paragraph, text: RichText(plainText: "Un"), note: note)
        let second = Block(order: 1, type: .paragraph, text: RichText(plainText: "Deux"), note: note)
        note.blocks = [first, second]
        let controller = EditorController(note: note)
        controller.updateBlockFrames(stackedFrames(for: [first, second]))
        controller.beginBlockDrag(second)

        // Tiers droit du premier bloc (largeur 600, tiers = 200 -- x = 550 > 400).
        let result = controller.performBlockDrop(pointerLocation: CGPoint(x: 550, y: 10))

        #expect(result)
        let topLevel = BlockOrdering.topLevelBlocks(of: note)
        #expect(topLevel.count == 1)
        #expect(topLevel.first?.type == .columnList)
        let columns = BlockOrdering.children(of: topLevel[0])
        #expect(BlockOrdering.children(of: columns[0]).first?.text?.plainText == "Un")
        #expect(BlockOrdering.children(of: columns[1]).first?.text?.plainText == "Deux")
    }

    @Test("Deposer sur le tiers d'un bloc DEJA en colonne ajoute une 3e colonne")
    func dropOnExistingColumnAddsAnotherColumn() throws {
        let note = Note(title: "Test")
        let first = Block(order: 0, type: .paragraph, text: RichText(plainText: "Un"), note: note)
        let second = Block(order: 1, type: .paragraph, text: RichText(plainText: "Deux"), note: note)
        let third = Block(order: 2, type: .paragraph, text: RichText(plainText: "Trois"), note: note)
        note.blocks = [first, second, third]
        let controller = EditorController(note: note)
        controller.updateBlockFrames(stackedFrames(for: [first, second, third]))
        controller.beginBlockDrag(second)
        _ = controller.performBlockDrop(pointerLocation: CGPoint(x: 550, y: 10))

        let columnList = try #require(BlockOrdering.topLevelBlocks(of: note).first { $0.type == .columnList })
        let columns = BlockOrdering.children(of: columnList)
        let unBlock = try #require(BlockOrdering.children(of: columns[0]).first)
        let deuxBlock = try #require(BlockOrdering.children(of: columns[1]).first)
        controller.updateBlockFrames(stackedFrames(for: [unBlock, deuxBlock]))
        controller.beginBlockDrag(third)

        // Tiers droit du bloc "Deux" (deuxieme colonne, deuxieme cadre : y en [40,80)).
        let result = controller.performBlockDrop(pointerLocation: CGPoint(x: 550, y: 50))

        #expect(result)
        #expect(BlockOrdering.children(of: columnList).count == 3)
    }

    // MARK: - Sortie/entree de colonne : integrite order/parent + purge (ModelContext reel)

    private struct Fixture {
        let controller: EditorController
        let note: Note
        let context: ModelContext
    }

    private func makeContextNote(paragraphs count: Int) throws -> Fixture {
        let container = try SlateContainer.make(inMemory: true)
        let context = ModelContext(container)
        let note = Note(title: "Test")
        context.insert(note)
        var blocks: [Block] = []
        for index in 0..<count {
            let block = Block(order: index, type: .paragraph, text: RichText(plainText: "Bloc \(index)"))
            block.note = note
            context.insert(block)
            blocks.append(block)
        }
        note.blocks = blocks
        try context.save()
        let controller = EditorController(note: note, modelContext: context)
        return Fixture(controller: controller, note: note, context: context)
    }

    @Test("Deplacer le SEUL contenu d'une colonne vers l'exterieur dissout la structure et purge le ModelContext")
    func movingOnlyColumnContentOutDissolvesAndPurges() throws {
        let fixture = try makeContextNote(paragraphs: 3)
        let blocks = BlockOrdering.topLevelBlocks(of: fixture.note)
        fixture.controller.updateBlockFrames(stackedFrames(for: blocks))
        fixture.controller.beginBlockDrag(blocks[1])
        _ = fixture.controller.performBlockDrop(pointerLocation: CGPoint(x: 550, y: 10))
        try fixture.context.save()

        let topLevel = BlockOrdering.topLevelBlocks(of: fixture.note)
        let columnList = try #require(topLevel.first { $0.type == .columnList })
        let secondColumn = BlockOrdering.children(of: columnList)[1]
        let movedContent = try #require(BlockOrdering.children(of: secondColumn).first)
        let remainingRoot = try #require(topLevel.first { $0.type != .columnList })
        let columnListID = columnList.id
        let secondColumnID = secondColumn.id

        fixture.controller.updateBlockFrames(stackedFrames(for: [remainingRoot]))
        fixture.controller.beginBlockDrag(movedContent)
        let result = fixture.controller.performBlockDrop(pointerLocation: CGPoint(x: 300, y: 35))
        try fixture.context.save()

        #expect(result)
        // La structure entiere a disparu (il ne restait qu'une colonne apres le retrait).
        #expect(!BlockOrdering.topLevelBlocks(of: fixture.note).contains { $0.type == .columnList })
        let remaining = try fixture.context.fetch(FetchDescriptor<Block>())
        #expect(!remaining.contains { $0.id == columnListID })
        #expect(!remaining.contains { $0.id == secondColumnID })
        #expect(remaining.contains { $0.id == movedContent.id })
    }

    @Test("Deplacer un bloc DANS une colonne existante lui donne le bon parent")
    func movingBlockIntoExistingColumnUpdatesParent() throws {
        let fixture = try makeContextNote(paragraphs: 3)
        let blocks = BlockOrdering.topLevelBlocks(of: fixture.note)
        fixture.controller.updateBlockFrames(stackedFrames(for: [blocks[0], blocks[1]]))
        fixture.controller.beginBlockDrag(blocks[1])
        _ = fixture.controller.performBlockDrop(pointerLocation: CGPoint(x: 550, y: 10))
        try fixture.context.save()

        let columnList = try #require(BlockOrdering.topLevelBlocks(of: fixture.note).first { $0.type == .columnList })
        let firstColumn = BlockOrdering.children(of: columnList)[0]
        let firstColumnContent = try #require(BlockOrdering.children(of: firstColumn).first)
        let outsideBlock = try #require(BlockOrdering.topLevelBlocks(of: fixture.note).first { $0.type != .columnList })

        fixture.controller.updateBlockFrames(stackedFrames(for: [firstColumnContent]))
        fixture.controller.beginBlockDrag(outsideBlock)
        let result = fixture.controller.performBlockDrop(pointerLocation: CGPoint(x: 300, y: 35))
        try fixture.context.save()

        #expect(result)
        #expect(outsideBlock.parent?.id == firstColumn.id)
        #expect(BlockOrdering.children(of: firstColumn).map(\.id) == [firstColumnContent.id, outsideBlock.id])
    }

    @Test("Aucun bloc ne reste orphelin dans le ModelContext apres une sequence de deplacements")
    func noBlockLeftOrphanedAfterSequenceOfMoves() throws {
        let fixture = try makeContextNote(paragraphs: 4)
        var blocks = BlockOrdering.topLevelBlocks(of: fixture.note)
        fixture.controller.updateBlockFrames(stackedFrames(for: blocks))
        fixture.controller.beginBlockDrag(blocks[0])
        _ = fixture.controller.performBlockDrop(pointerLocation: CGPoint(x: 300, y: 3 * 40 + 35))
        try fixture.context.save()

        blocks = BlockOrdering.topLevelBlocks(of: fixture.note)
        fixture.controller.updateBlockFrames(stackedFrames(for: blocks))
        fixture.controller.beginBlockDrag(blocks[2])
        _ = fixture.controller.performBlockDrop(pointerLocation: CGPoint(x: 550, y: 5))
        try fixture.context.save()

        let allBlocks = BlockOrdering.flattenedBlocks(of: fixture.note)
        let contextBlocks = try fixture.context.fetch(FetchDescriptor<Block>())
        // Chaque bloc encore rattache a la note doit exister dans le ModelContext, et
        // aucun bloc du ModelContext ne doit etre un fantome deconnecte de la note.
        for block in allBlocks {
            #expect(contextBlocks.contains { $0.id == block.id })
        }
        for stored in contextBlocks {
            #expect(stored.note != nil, "un bloc du ModelContext ne doit jamais perdre sa note")
        }
    }
}
