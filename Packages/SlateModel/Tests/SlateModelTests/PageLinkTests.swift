import Foundation
import SwiftData
import Testing

@testable import SlateModel

/// Tests de Phase 16 (`docs/16_liens_internes.md`) cote `SlateModel` : resolution de
/// l'URL interne `slate://note/<uuid>`, et requete inverse des backlinks.
@MainActor
struct SlateNoteURLResolverTests {
    @Test
    func urlAndBackAreSymmetric() {
        let noteID = UUID()
        let url = SlateNoteURLResolver.url(forNoteID: noteID)
        #expect(SlateNoteURLResolver.noteID(in: url) == noteID)
    }

    @Test
    func rejectsOtherSchemes() throws {
        let url = try #require(URL(string: "https://note/\(UUID().uuidString)"))
        #expect(SlateNoteURLResolver.noteID(in: url) == nil)
    }

    @Test
    func rejectsOtherHosts() throws {
        let url = try #require(URL(string: "slate://folder/\(UUID().uuidString)"))
        #expect(SlateNoteURLResolver.noteID(in: url) == nil)
    }

    @Test
    func rejectsNonUUIDPath() throws {
        let url = try #require(URL(string: "slate://note/not-a-uuid"))
        #expect(SlateNoteURLResolver.noteID(in: url) == nil)
    }
}

@MainActor
struct PageLinkBacklinksTests {
    @Test
    func findsNotesLinkingToTarget() throws {
        let container = try SlateContainer.make(inMemory: true)
        let context = ModelContext(container)

        let target = Note(title: "Cible")
        let source = Note(title: "Source")
        context.insert(target)
        context.insert(source)

        var attributes = BlockAttributes()
        attributes.linkedNoteID = target.id
        let linkBlock = Block(type: .pageLink, attributes: attributes, note: source)
        context.insert(linkBlock)
        source.blocks = [linkBlock]
        try context.save()

        let backlinks = try PageLinkBacklinks.notes(linkingTo: target, in: context)
        #expect(backlinks.map(\.id) == [source.id])
    }

    @Test
    func excludesUnrelatedPageLinksAndSelfLinks() throws {
        let container = try SlateContainer.make(inMemory: true)
        let context = ModelContext(container)

        let target = Note(title: "Cible")
        let unrelatedTarget = Note(title: "Autre cible")
        let unrelatedSource = Note(title: "Non concernee")
        context.insert(target)
        context.insert(unrelatedTarget)
        context.insert(unrelatedSource)

        var attributes = BlockAttributes()
        attributes.linkedNoteID = unrelatedTarget.id
        let unrelatedBlock = Block(type: .pageLink, attributes: attributes, note: unrelatedSource)
        context.insert(unrelatedBlock)
        unrelatedSource.blocks = [unrelatedBlock]

        var selfAttributes = BlockAttributes()
        selfAttributes.linkedNoteID = target.id
        let selfBlock = Block(type: .pageLink, attributes: selfAttributes, note: target)
        context.insert(selfBlock)
        target.blocks = [selfBlock]
        try context.save()

        let backlinks = try PageLinkBacklinks.notes(linkingTo: target, in: context)
        #expect(backlinks.isEmpty)
    }

    @Test
    func noBacklinksReturnsEmptyArray() throws {
        let container = try SlateContainer.make(inMemory: true)
        let context = ModelContext(container)
        let target = Note(title: "Cible")
        context.insert(target)
        try context.save()

        #expect(try PageLinkBacklinks.notes(linkingTo: target, in: context).isEmpty)
    }
}
