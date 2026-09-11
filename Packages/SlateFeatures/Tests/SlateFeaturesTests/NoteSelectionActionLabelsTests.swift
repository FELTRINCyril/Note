import Foundation
import Testing
@testable import SlateFeatures

/// Libelles comptes du menu contextuel de note en selection multiple (design P3,
/// artboard A : "Mettre 3 notes a la corbeille"). `locale` toujours injecte
/// explicitement. Meme technique que `NoteHeaderMetadataFormatterTests` : l'attendu est
/// RECOMPOSE a partir des memes cles/gabarits localises plutot que fige en dur, pour
/// rester correct que le catalogue de chaines soit reellement compile (Xcode) ou non
/// (`swift test` en CLI ne compile pas les `.xcstrings`, voir le rapport de phase).
@Suite("NoteSelectionActionLabels")
struct NoteSelectionActionLabelsTests {
    private let locale = Locale(identifier: "fr_FR")

    private func localized(_ key: String) -> String {
        String(localized: String.LocalizationValue(key), bundle: .module, locale: locale)
    }

    @Test("Une seule note : libelle singulier, distinct du libelle pluriel")
    func moveToTrashSingular() {
        let expected = localized("noteList.contextMenu.moveToTrash.one")
        #expect(NoteSelectionActionLabels.moveToTrash(count: 1, locale: locale) == expected)
    }

    @Test("Plusieurs notes : libelle compte au pluriel, avec le nombre injecte")
    func moveToTrashPlural() {
        let template = localized("noteList.contextMenu.moveToTrash.many")
        let expected = String(format: template, 3)
        #expect(NoteSelectionActionLabels.moveToTrash(count: 3, locale: locale) == expected)
    }

    @Test("Dupliquer : singulier sans nombre, pluriel compte")
    func duplicateLabels() {
        let expectedOne = localized("noteList.contextMenu.duplicate.one")
        #expect(NoteSelectionActionLabels.duplicate(count: 1, locale: locale) == expectedOne)

        let template = localized("noteList.contextMenu.duplicate.many")
        let expectedMany = String(format: template, 5)
        #expect(NoteSelectionActionLabels.duplicate(count: 5, locale: locale) == expectedMany)
    }

    @Test("Ajouter aux favoris : singulier sans nombre, pluriel compte")
    func addFavoriteLabels() {
        let expectedOne = localized("noteList.contextMenu.favorite.add.one")
        #expect(NoteSelectionActionLabels.addFavorite(count: 1, locale: locale) == expectedOne)

        let template = localized("noteList.contextMenu.favorite.add.many")
        let expectedMany = String(format: template, 4)
        #expect(NoteSelectionActionLabels.addFavorite(count: 4, locale: locale) == expectedMany)
    }

    @Test("Retirer des favoris : singulier sans nombre, pluriel compte")
    func removeFavoriteLabels() {
        let expectedOne = localized("noteList.contextMenu.favorite.remove.one")
        #expect(NoteSelectionActionLabels.removeFavorite(count: 1, locale: locale) == expectedOne)

        let template = localized("noteList.contextMenu.favorite.remove.many")
        let expectedMany = String(format: template, 2)
        #expect(NoteSelectionActionLabels.removeFavorite(count: 2, locale: locale) == expectedMany)
    }

    @Test("En-tete de selection multiple compte le nombre de notes")
    func selectionHeaderPlural() {
        let template = localized("noteList.contextMenu.selectionHeader.many")
        let expected = String(format: template, 3)
        #expect(NoteSelectionActionLabels.selectionHeader(count: 3, locale: locale) == expected)
    }

    @Test("Singulier et pluriel restent des libelles distincts")
    func singularAndPluralDiffer() {
        #expect(
            NoteSelectionActionLabels.moveToTrash(count: 1, locale: locale)
                != NoteSelectionActionLabels.moveToTrash(count: 3, locale: locale)
        )
        #expect(
            NoteSelectionActionLabels.duplicate(count: 1, locale: locale)
                != NoteSelectionActionLabels.duplicate(count: 5, locale: locale)
        )
    }
}
