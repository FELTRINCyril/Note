import Testing
import SlateModel
@testable import SlateFeatures

/// Test de la regle "en tri par titre, les groupes de date s'aplatissent" (spec E3,
/// `docs/04_liste_notes.md`), releve en revue de fin de Phase 4 comme non couvert : ce
/// point de decision vivait seulement inline dans `NoteListView.listScrollView`, sans
/// test dedie. Extrait en fonction pure et testee ici - voir la documentation de
/// `NoteListView.shouldFlattenDateGroups(for:)`.
@Suite("NoteListView.shouldFlattenDateGroups")
struct NoteListViewLogicTests {
    @Test("Le tri par titre aplatit les groupes de date")
    func titleSortFlattens() {
        #expect(NoteListView.shouldFlattenDateGroups(for: .title))
    }

    @Test("Le tri par date de modification garde les groupes de date")
    func modifiedDateSortKeepsGroups() {
        #expect(!NoteListView.shouldFlattenDateGroups(for: .modifiedDate))
    }

    @Test("Le tri par date de creation garde les groupes de date")
    func createdDateSortKeepsGroups() {
        #expect(!NoteListView.shouldFlattenDateGroups(for: .createdDate))
    }
}

/// Test du correctif de performance de fin de Phase 4 (`NoteListView` appelait
/// `NoteListQuery.notes(in:...)` jusqu'a 5 fois par rendu - deux requetes triees
/// independamment, `.pinnedOnly` puis `.excludingPinned`, etaient utilisees pour
/// separer les notes epinglees du reste). `partitionByPinned` remplace ces deux
/// requetes par une seule requete `.all` suivie d'un partitionnement en memoire ; ces
/// tests verifient que ce partitionnement preserve rigoureusement l'ordre d'entree et
/// ne perd ni ne duplique jamais aucune note - voir la documentation de
/// `NoteListView.partitionByPinned(_:)`.
@Suite("NoteListView.partitionByPinned")
@MainActor
struct NoteListViewPartitionByPinnedTests {
    @Test("Liste vide : deux listes vides")
    func emptyList() {
        let (pinned, rest) = NoteListView.partitionByPinned([])
        #expect(pinned.isEmpty)
        #expect(rest.isEmpty)
    }

    @Test("Aucune note epinglee : tout dans le reste, ordre preserve")
    func noPinnedNotes() {
        let first = Note(title: "A")
        let second = Note(title: "B")
        let third = Note(title: "C")
        let notes = [first, second, third]

        let (pinned, rest) = NoteListView.partitionByPinned(notes)

        #expect(pinned.isEmpty)
        #expect(rest.map(\.id) == notes.map(\.id))
    }

    @Test("Toutes les notes epinglees : tout dans les epinglees, ordre preserve")
    func allPinnedNotes() {
        let first = Note(title: "A", isPinned: true)
        let second = Note(title: "B", isPinned: true)
        let notes = [first, second]

        let (pinned, rest) = NoteListView.partitionByPinned(notes)

        #expect(rest.isEmpty)
        #expect(pinned.map(\.id) == notes.map(\.id))
    }

    @Test("Melange : chaque groupe preserve l'ordre relatif d'entree, sans perte ni duplication")
    func mixedPinnedAndUnpinnedNotesPreserveRelativeOrder() {
        let pinnedFirst = Note(title: "Epinglee 1", isPinned: true)
        let regularFirst = Note(title: "Normale 1", isPinned: false)
        let pinnedSecond = Note(title: "Epinglee 2", isPinned: true)
        let regularSecond = Note(title: "Normale 2", isPinned: false)
        let notes = [pinnedFirst, regularFirst, pinnedSecond, regularSecond]

        let (pinned, rest) = NoteListView.partitionByPinned(notes)

        #expect(pinned.map(\.id) == [pinnedFirst.id, pinnedSecond.id])
        #expect(rest.map(\.id) == [regularFirst.id, regularSecond.id])
    }

    @Test("Aucune note n'est perdue ni dupliquee entre les deux groupes")
    func noNoteIsLostOrDuplicated() {
        let notes = (0..<10).map { index in
            Note(title: "Note \(index)", isPinned: index.isMultiple(of: 3))
        }

        let (pinned, rest) = NoteListView.partitionByPinned(notes)

        #expect(Set(pinned.map(\.id)).isDisjoint(with: Set(rest.map(\.id))))
        #expect(Set(pinned.map(\.id)).union(rest.map(\.id)) == Set(notes.map(\.id)))
        #expect(pinned.count + rest.count == notes.count)
    }
}
