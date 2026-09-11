import Foundation
import Testing
@testable import SlateFeatures

/// Libelle d'expiration d'une note en corbeille (design P3, artboard B : "expire dans
/// 28 jours" / "expire demain"). `locale` toujours injecte explicitement. Meme
/// technique que `NoteHeaderMetadataFormatterTests` pour l'attendu (voir
/// `NoteSelectionActionLabelsTests`).
@Suite("TrashExpirationFormatter")
struct TrashExpirationFormatterTests {
    private let locale = Locale(identifier: "fr_FR")

    private func localized(_ key: String) -> String {
        String(localized: String.LocalizationValue(key), bundle: .module, locale: locale)
    }

    @Test("28 jours restants : gabarit pluriel avec le nombre")
    func manyDaysRemaining() {
        let expected = String(format: localized("trash.expiration.days"), 28)
        #expect(TrashExpirationFormatter.string(remainingDays: 28, locale: locale) == expected)
    }

    @Test("2 jours restants : meme gabarit pluriel (borne basse)")
    func twoDaysRemaining() {
        let expected = String(format: localized("trash.expiration.days"), 2)
        #expect(TrashExpirationFormatter.string(remainingDays: 2, locale: locale) == expected)
    }

    @Test("1 jour restant : gabarit 'demain', distinct du gabarit pluriel")
    func oneDayRemaining() {
        let expected = localized("trash.expiration.tomorrow")
        #expect(TrashExpirationFormatter.string(remainingDays: 1, locale: locale) == expected)
        #expect(expected != String(format: localized("trash.expiration.days"), 1))
    }

    @Test("0 jour restant : gabarit 'aujourd'hui'")
    func zeroDaysRemaining() {
        let expected = localized("trash.expiration.today")
        #expect(TrashExpirationFormatter.string(remainingDays: 0, locale: locale) == expected)
    }

    @Test("Jours negatifs (deja due a la purge) : traite comme aujourd'hui, jamais un nombre negatif")
    func negativeDaysRemaining() {
        let expected = localized("trash.expiration.today")
        #expect(TrashExpirationFormatter.string(remainingDays: -3, locale: locale) == expected)
    }

    private func date(
        _ calendar: Calendar,
        _ year: Int,
        _ month: Int,
        _ day: Int,
        hour: Int,
        minute: Int = 0
    ) throws -> Date {
        let components = DateComponents(year: year, month: month, day: day, hour: hour, minute: minute)
        return try #require(calendar.date(from: components))
    }

    @Test("Bout en bout : trashedAt + 30 jours de retention, 2 jours plus tard, tombe sur le gabarit pluriel avec 28")
    func endToEndFromTrashedAt() throws {
        let calendar = Calendar(identifier: .gregorian)
        let now = try date(calendar, 2026, 1, 3, hour: 10)
        let trashedAt = try date(calendar, 2026, 1, 1, hour: 14, minute: 22)

        let result = TrashExpirationFormatter.string(trashedAt: trashedAt, now: now, calendar: calendar, locale: locale)
        let expected = String(format: localized("trash.expiration.days"), 28)

        #expect(result == expected)
    }

    @Test("Bout en bout : a J+29 (1 jour restant), tombe sur le gabarit 'demain'")
    func endToEndExpiresTomorrow() throws {
        let calendar = Calendar(identifier: .gregorian)
        let now = try date(calendar, 2026, 1, 30, hour: 9)
        let trashedAt = try date(calendar, 2026, 1, 1, hour: 14, minute: 22)

        let result = TrashExpirationFormatter.string(trashedAt: trashedAt, now: now, calendar: calendar, locale: locale)

        #expect(result == localized("trash.expiration.tomorrow"))
    }
}
