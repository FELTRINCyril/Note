import Foundation
import SlateModel
import SwiftData
import Testing

@testable import SlateEditor

/// Selecteur de page "@"/"[[" (Phase 16, docs/16_liens_internes.md) : detection
/// d'ouverture/fermeture, filtrage, insertion d'un lien vers une note existante,
/// creation d'une page a la volee, et resolution du titre (y compris orpheline) via
/// `PageLinkBlockContentView`/`SlateNoteURLResolver` (testes cote pur ici, la vue
/// SwiftUI elle-meme n'est pas instanciee -- meme limite que documentee pour le reste
/// de `SlateEditor`, voir `EditorControllerTests`).
@MainActor
@Suite("EditorController.PageMention")
struct EditorControllerPageMentionTests {
    private struct Fixture {
        let controller: EditorController
        let note: Note
        let context: ModelContext
    }

    /// Note d'un seul paragraphe dans un vrai `ModelContext` en memoire -- necessaire
    /// ici (contrairement au menu "/") : la recherche de page interroge reellement
    /// `ModelContext.fetch` (voir `EditorController+PageMention.swift`,
    /// `pageMentionCandidates()`).
    private func makeNote(text: String = "") throws -> Fixture {
        let container = try SlateContainer.make(inMemory: true)
        let context = ModelContext(container)
        let note = Note(title: "Note courante")
        context.insert(note)
        let block = Block(order: 0, type: .paragraph, text: RichText(plainText: text))
        block.note = note
        context.insert(block)
        note.blocks = [block]
        try context.save()

        let controller = EditorController(note: note, modelContext: context)
        return Fixture(controller: controller, note: note, context: context)
    }

    @discardableResult
    private func makeOtherNote(_ fixture: Fixture, title: String) throws -> Note {
        let other = Note(title: title)
        fixture.context.insert(other)
        try fixture.context.save()
        return other
    }

    // MARK: - Detection d'ouverture

    @Test("Le @ tape en debut de bloc ouvre le selecteur, requete vide")
    func atSignAtBlockStartOpensSelector() throws {
        let fixture = try makeNote()
        let block = try #require(BlockOrdering.topLevelBlocks(of: fixture.note).first)

        fixture.controller.updatePageMentionState(for: block, plainText: "@", caretOffset: 1)

        #expect(fixture.controller.pageMentionState?.blockID == block.id)
        #expect(fixture.controller.pageMentionState?.query.isEmpty == true)
    }

    @Test("[[ tape en debut de bloc ouvre aussi le selecteur")
    func doubleBracketOpensSelector() throws {
        let fixture = try makeNote()
        let block = try #require(BlockOrdering.topLevelBlocks(of: fixture.note).first)

        fixture.controller.updatePageMentionState(for: block, plainText: "[[", caretOffset: 2)

        #expect(fixture.controller.pageMentionState != nil)
    }

    @Test("Le @ au milieu d'un mot (adresse mail) n'ouvre jamais le selecteur")
    func atSignInsideWordDoesNotOpenSelector() throws {
        let fixture = try makeNote()
        let block = try #require(BlockOrdering.topLevelBlocks(of: fixture.note).first)

        fixture.controller.updatePageMentionState(for: block, plainText: "cyril@gemaddis", caretOffset: 6)

        #expect(fixture.controller.pageMentionState == nil)
    }

    @Test("Le / a priorite absolue : le @ n'ouvre rien tant que le menu / est ouvert")
    func slashMenuTakesPriorityOverPageMention() throws {
        let fixture = try makeNote()
        let block = try #require(BlockOrdering.topLevelBlocks(of: fixture.note).first)
        fixture.controller.updateSlashMenuState(for: block, plainText: "/", caretOffset: 1)

        fixture.controller.updatePageMentionState(for: block, plainText: "/@", caretOffset: 2)

        #expect(fixture.controller.pageMentionState == nil)
    }

    // MARK: - Mise a jour de la requete / fermeture

    @Test("La requete se met a jour a mesure que le caret avance")
    func queryUpdatesAsCaretAdvances() throws {
        let fixture = try makeNote()
        let block = try #require(BlockOrdering.topLevelBlocks(of: fixture.note).first)
        fixture.controller.updatePageMentionState(for: block, plainText: "@", caretOffset: 1)

        fixture.controller.updatePageMentionState(for: block, plainText: "@Reu", caretOffset: 4)

        #expect(fixture.controller.pageMentionState?.query == "Reu")
    }

    @Test("Une requete multi-mots reste ouverte meme sans aucun resultat (contrairement au /)")
    func multiWordQueryWithoutResultsStaysOpen() throws {
        let fixture = try makeNote()
        let block = try #require(BlockOrdering.topLevelBlocks(of: fixture.note).first)
        fixture.controller.updatePageMentionState(for: block, plainText: "@", caretOffset: 1)

        fixture.controller.updatePageMentionState(
            for: block, plainText: "@Reunion clients importants", caretOffset: 27
        )

        #expect(fixture.controller.pageMentionState?.query == "Reunion clients importants")
    }

    @Test("Fermeture : une seule espace juste apres le declencheur ferme le selecteur")
    func closesOnEntirelyWhitespaceQuery() throws {
        let fixture = try makeNote()
        let block = try #require(BlockOrdering.topLevelBlocks(of: fixture.note).first)
        fixture.controller.updatePageMentionState(for: block, plainText: "@", caretOffset: 1)

        fixture.controller.updatePageMentionState(for: block, plainText: "@ ", caretOffset: 2)

        #expect(fixture.controller.pageMentionState == nil)
    }

    // MARK: - Insertion d'un lien vers une note existante

    @Test("Selectionner une note insere un bloc pageLink en place d'un bloc vide, puis un paragraphe focalise")
    func selectingExistingNoteInsertsPageLinkInPlaceWhenBlockBecomesEmpty() throws {
        let fixture = try makeNote(text: "@Reunion")
        let target = try makeOtherNote(fixture, title: "Reunion clients")
        let block = try #require(BlockOrdering.topLevelBlocks(of: fixture.note).first)
        fixture.controller.updatePageMentionState(for: block, plainText: "@", caretOffset: 1)
        fixture.controller.updatePageMentionState(for: block, plainText: "@Reunion", caretOffset: 8)

        let matches = fixture.controller.pageMentionMatches(for: block)
        #expect(matches.map(\.candidate.id) == [target.id])

        fixture.controller.confirmPageMentionSelection(target.id.uuidString, in: block)

        let blocks = BlockOrdering.topLevelBlocks(of: fixture.note)
        #expect(blocks.count == 2)
        #expect(blocks[0].id == block.id)
        #expect(blocks[0].type == .pageLink)
        #expect(blocks[0].attributes.linkedNoteID == target.id)
        #expect(blocks[1].type == .paragraph)
        #expect(fixture.controller.pageMentionState == nil)
    }

    @Test("Selectionner une note avec du texte autour insere un NOUVEAU bloc pageLink en dessous")
    func selectingExistingNoteInsertsPageLinkBelowWhenTextRemains() throws {
        let fixture = try makeNote(text: "Voir @Reunion pour plus de details")
        let target = try makeOtherNote(fixture, title: "Reunion clients")
        let block = try #require(BlockOrdering.topLevelBlocks(of: fixture.note).first)
        fixture.controller.updatePageMentionState(for: block, plainText: "Voir @", caretOffset: 6)
        fixture.controller.updatePageMentionState(for: block, plainText: "Voir @Reunion", caretOffset: 13)

        fixture.controller.confirmPageMentionSelection(target.id.uuidString, in: block)

        let blocks = BlockOrdering.topLevelBlocks(of: fixture.note)
        #expect(blocks.count == 3)
        #expect(blocks[0].id == block.id)
        #expect(blocks[0].type == .paragraph)
        #expect(blocks[1].type == .pageLink)
        #expect(blocks[1].attributes.linkedNoteID == target.id)
        #expect(blocks[2].type == .paragraph)
    }

    // MARK: - Creation d'une page a la volee

    @Test("Creer la page X quand aucun resultat cree une note et insere le lien vers elle")
    func creatingNewPageInsertsLinkToBrandNewNote() throws {
        let fixture = try makeNote(text: "@Projet Alpha")
        let block = try #require(BlockOrdering.topLevelBlocks(of: fixture.note).first)
        fixture.controller.updatePageMentionState(for: block, plainText: "@", caretOffset: 1)
        fixture.controller.updatePageMentionState(for: block, plainText: "@Projet Alpha", caretOffset: 13)

        #expect(fixture.controller.shouldOfferPageMentionCreation(for: block))

        fixture.controller.confirmPageMentionSelection(EditorController.pageMentionCreateSentinel, in: block)

        let blocks = BlockOrdering.topLevelBlocks(of: fixture.note)
        #expect(blocks[0].type == .pageLink)
        let linkedID = try #require(blocks[0].attributes.linkedNoteID)

        let descriptor = FetchDescriptor<Note>(predicate: #Predicate { $0.id == linkedID })
        let createdNote = try #require(try fixture.context.fetch(descriptor).first)
        #expect(createdNote.title == "Projet Alpha")
    }

    @Test("Ne propose jamais 'Creer' si une note correspond deja")
    func doesNotOfferCreationWhenMatchExists() throws {
        let fixture = try makeNote(text: "@Reunion")
        try makeOtherNote(fixture, title: "Reunion clients")
        let block = try #require(BlockOrdering.topLevelBlocks(of: fixture.note).first)
        fixture.controller.updatePageMentionState(for: block, plainText: "@", caretOffset: 1)
        fixture.controller.updatePageMentionState(for: block, plainText: "@Reunion", caretOffset: 8)

        #expect(!fixture.controller.shouldOfferPageMentionCreation(for: block))
    }

    // MARK: - Titre resolu dynamiquement (renommage) et orphelins

    @Test("Le titre d'un lien suit un renommage de la note ciblee (jamais stocke sur le bloc)")
    func linkedNoteTitleIsNeverStoredOnTheBlock() throws {
        let fixture = try makeNote(text: "@Reunion")
        let target = try makeOtherNote(fixture, title: "Reunion clients")
        let block = try #require(BlockOrdering.topLevelBlocks(of: fixture.note).first)
        fixture.controller.updatePageMentionState(for: block, plainText: "@", caretOffset: 1)
        fixture.controller.updatePageMentionState(for: block, plainText: "@Reunion", caretOffset: 8)
        fixture.controller.confirmPageMentionSelection(target.id.uuidString, in: block)
        let linkBlock = try #require(BlockOrdering.topLevelBlocks(of: fixture.note).first)
        let linkedID = try #require(linkBlock.attributes.linkedNoteID)

        target.title = "Reunion clients (reportee)"
        try fixture.context.save()

        // Rien sur `BlockAttributes` ne porte de titre : la resolution passe TOUJOURS
        // par `linkedNoteID` -> `ModelContext.fetch`, voir `PageLinkBlockContentView`.
        let descriptor = FetchDescriptor<Note>(predicate: #Predicate<Note> { $0.id == linkedID })
        let resolved = try #require(try fixture.context.fetch(descriptor).first)
        #expect(resolved.title == "Reunion clients (reportee)")
    }

    @Test("Une cible supprimee laisse un linkedNoteID orphelin, jamais resolu, jamais un crash")
    func deletedTargetLeavesAnUnresolvableButHarmlessOrphan() throws {
        let fixture = try makeNote(text: "@Reunion")
        let target = try makeOtherNote(fixture, title: "Reunion clients")
        let block = try #require(BlockOrdering.topLevelBlocks(of: fixture.note).first)
        fixture.controller.updatePageMentionState(for: block, plainText: "@", caretOffset: 1)
        fixture.controller.updatePageMentionState(for: block, plainText: "@Reunion", caretOffset: 8)
        fixture.controller.confirmPageMentionSelection(target.id.uuidString, in: block)
        let linkBlock = try #require(BlockOrdering.topLevelBlocks(of: fixture.note).first)
        let linkedID = try #require(linkBlock.attributes.linkedNoteID)

        fixture.context.delete(target)
        try fixture.context.save()

        let descriptor = FetchDescriptor<Note>(predicate: #Predicate { $0.id == linkedID })
        let resolved = try fixture.context.fetch(descriptor).first
        #expect(resolved == nil)
        // Le bloc lui-meme reste intact, `linkedNoteID` inchange -- c'est a la vue
        // (`PageLinkBlockContentView`) de traduire ce `nil` en etat "page supprimee".
        #expect(linkBlock.attributes.linkedNoteID == linkedID)
    }

    // MARK: - Echap / Entree

    @Test("Echap ferme le selecteur seul, sans rien inserer")
    func escapeClosesSelectorWithoutInserting() throws {
        let fixture = try makeNote(text: "@Reu")
        let block = try #require(BlockOrdering.topLevelBlocks(of: fixture.note).first)
        fixture.controller.updatePageMentionState(for: block, plainText: "@", caretOffset: 1)
        fixture.controller.updatePageMentionState(for: block, plainText: "@Reu", caretOffset: 4)

        let handled = fixture.controller.handlePageMentionEscape(in: block)

        #expect(handled)
        #expect(fixture.controller.pageMentionState == nil)
        #expect(BlockOrdering.topLevelBlocks(of: fixture.note).count == 1)
    }
}
