import Foundation
import Testing

@testable import SlateEditor

/// Filtrage flou du selecteur de page "@"/"[[" (Phase 16, docs/16_liens_internes.md).
/// Logique PURE, testee sans `ModelContext`/`EditorController` -- voir la documentation
/// de tete de `PageMentionFilter`.
@Suite("PageMentionFilter")
struct PageMentionFilterTests {
    private func candidate(_ title: String) -> NoteMentionCandidate {
        NoteMentionCandidate(id: UUID(), title: title)
    }

    @Test("Requete vide retourne toutes les notes, triees par titre")
    func emptyQueryReturnsAllSortedByTitle() {
        let zebra = candidate("Zebre")
        let alpha = candidate("Alpha")
        let matches = PageMentionFilter.match(query: "", in: [zebra, alpha])
        #expect(matches.map(\.candidate.title) == ["Alpha", "Zebre"])
    }

    @Test("Prefixe exact classe avant un simple 'contient'")
    func prefixOutranksContains() {
        let containsOnly = candidate("Compte-rendu Reunion")
        let prefix = candidate("Reunion clients")
        let matches = PageMentionFilter.match(query: "Reunion", in: [containsOnly, prefix])
        #expect(matches.map(\.candidate.id) == [prefix.id, containsOnly.id])
    }

    @Test("Sous-sequence non contigue matche quand meme (dernier niveau)")
    func subsequenceStillMatches() {
        let note = candidate("Titre")
        let matches = PageMentionFilter.match(query: "tie", in: [note])
        #expect(matches.map(\.candidate.id) == [note.id])
    }

    @Test("Insensible a la casse et aux diacritiques")
    func foldsCaseAndDiacritics() {
        let note = candidate("Réunion")
        let matches = PageMentionFilter.match(query: "reunion", in: [note])
        #expect(matches.map(\.candidate.id) == [note.id])
    }

    @Test("Aucune correspondance exclut la note du resultat")
    func noMatchExcludesCandidate() {
        let note = candidate("Alpha")
        let matches = PageMentionFilter.match(query: "zzz", in: [note])
        #expect(matches.isEmpty)
    }
}
