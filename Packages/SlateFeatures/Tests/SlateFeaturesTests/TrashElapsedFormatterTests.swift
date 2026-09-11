import Foundation
import Testing
@testable import SlateFeatures

/// Libelle "Supprimee il y a N jours" (design P3, artboard B). `locale` toujours
/// injecte explicitement. Meme technique que `NoteSelectionActionLabelsTests` pour
/// l'attendu.
@Suite("TrashElapsedFormatter")
struct TrashElapsedFormatterTests {
    private let locale = Locale(identifier: "fr_FR")

    private func localized(_ key: String) -> String {
        String(localized: String.LocalizationValue(key), bundle: .module, locale: locale)
    }

    @Test("2 jours ecoules : gabarit pluriel avec le nombre")
    func twoDaysElapsed() {
        let expected = String(format: localized("trash.elapsed.manyDays"), 2)
        #expect(TrashElapsedFormatter.string(elapsedDays: 2, locale: locale) == expected)
    }

    @Test("1 jour ecoule : gabarit singulier, distinct du pluriel")
    func oneDayElapsed() {
        let expected = localized("trash.elapsed.oneDay")
        #expect(TrashElapsedFormatter.string(elapsedDays: 1, locale: locale) == expected)
        #expect(expected != String(format: localized("trash.elapsed.manyDays"), 1))
    }

    @Test("0 jour ecoule : gabarit 'aujourd'hui'")
    func zeroDaysElapsed() {
        let expected = localized("trash.elapsed.today")
        #expect(TrashElapsedFormatter.string(elapsedDays: 0, locale: locale) == expected)
    }
}
