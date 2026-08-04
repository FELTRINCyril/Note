import Foundation
import Testing
@testable import SlateFeatures

/// Tests de `NoteHeaderMetadataFormatter` (spec E4 : "Modifiee aujourd'hui a 14:22 -
/// 428 mots"). Meme discipline de determinisme que `NoteRelativeDateFormatterTests`
/// (`calendar`/`locale`/`now` toujours injectes).
///
/// Comme `NoteRelativeDateFormatterTests` le documente : `swift test` en CLI ne
/// compile pas `Localizable.xcstrings` pour le bundle de test, donc
/// `String(localized:bundle:)` y retombe sur la cle brute -- et, ici, sur un gabarit
/// brut SANS "%@" (la cle elle-meme), ce qui fait que `String(format:)` ignore purement
/// et simplement les arguments passes. Ces tests reconstruisent donc le resultat
/// attendu avec les MEMES primitives que l'implementation (jamais un texte traduit
/// fige en dur), ce qui les rend valables aussi bien sous `swift test` (egalite
/// triviale des deux cotes) que sous `xcodebuild test` (ou le catalogue est reellement
/// compile et la substitution "%@" a lieu pour de vrai des deux cotes).
@Suite("NoteHeaderMetadataFormatter")
struct NoteHeaderMetadataFormatterTests {
    private func parisCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Paris") ?? .current
        return calendar
    }

    private func makeDate(
        year: Int,
        month: Int,
        day: Int,
        hour: Int,
        minute: Int = 0,
        calendar: Calendar
    ) throws -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        return try #require(calendar.date(from: components))
    }

    /// Reconstruit le resultat attendu avec les memes primitives que
    /// `NoteHeaderMetadataFormatter.string(...)` : gabarit "noteHeader.metadataLine",
    /// jour deja forme, heure "HH:mm", et gabarit de mots singulier/pluriel.
    private func expectedLine(day: String, time: String, wordCount: Int, locale: Locale) -> String {
        let template = String(localized: "noteHeader.metadataLine", bundle: .module, locale: locale)
        let pluralTemplate = String(localized: "noteHeader.wordCount.plural", bundle: .module, locale: locale)
        let words = wordCount == 1
            ? String(localized: "noteHeader.wordCount.singular", bundle: .module, locale: locale)
            : String(format: pluralTemplate, wordCount)
        return String(format: template, day, time, words)
    }

    @Test("Aujourd'hui : le gabarit de jour 'today' et l'heure sont composes")
    func todayComposesTodayTemplate() throws {
        let calendar = parisCalendar()
        let locale = Locale(identifier: "fr_FR")
        let now = try makeDate(year: 2026, month: 8, day: 3, hour: 15, calendar: calendar)
        let date = try makeDate(year: 2026, month: 8, day: 3, hour: 14, minute: 22, calendar: calendar)

        let result = NoteHeaderMetadataFormatter.string(
            modifiedAt: date, wordCount: 428, calendar: calendar, locale: locale, now: now
        )

        let expectedDay = String(localized: "noteHeader.day.today", bundle: .module, locale: locale)
        let expected = expectedLine(day: expectedDay, time: "14:22", wordCount: 428, locale: locale)

        #expect(result == expected)
    }

    @Test("Hier : le gabarit de jour 'yesterday' est utilise")
    func yesterdayComposesYesterdayTemplate() throws {
        let calendar = parisCalendar()
        let locale = Locale(identifier: "fr_FR")
        let now = try makeDate(year: 2026, month: 8, day: 3, hour: 15, calendar: calendar)
        let date = try makeDate(year: 2026, month: 8, day: 2, hour: 9, minute: 12, calendar: calendar)

        let result = NoteHeaderMetadataFormatter.string(
            modifiedAt: date, wordCount: 1_204, calendar: calendar, locale: locale, now: now
        )

        let expectedDay = String(localized: "noteHeader.day.yesterday", bundle: .module, locale: locale)
        let expected = expectedLine(day: expectedDay, time: "09:12", wordCount: 1_204, locale: locale)

        #expect(result == expected)
    }

    @Test("Un seul mot utilise le gabarit singulier, pas le pluriel")
    func singleWordUsesSingularTemplate() throws {
        let calendar = parisCalendar()
        let locale = Locale(identifier: "fr_FR")
        let now = try makeDate(year: 2026, month: 8, day: 3, hour: 15, calendar: calendar)

        let result = NoteHeaderMetadataFormatter.string(
            modifiedAt: now, wordCount: 1, calendar: calendar, locale: locale, now: now
        )

        let expectedDay = String(localized: "noteHeader.day.today", bundle: .module, locale: locale)
        let expected = expectedLine(day: expectedDay, time: "15:00", wordCount: 1, locale: locale)

        #expect(result == expected)
    }

    @Test("Zero mot utilise le gabarit pluriel (0 n'est pas singulier)")
    func zeroWordsUsesPluralTemplate() throws {
        let calendar = parisCalendar()
        let locale = Locale(identifier: "fr_FR")
        let now = try makeDate(year: 2026, month: 8, day: 3, hour: 15, calendar: calendar)

        let result = NoteHeaderMetadataFormatter.string(
            modifiedAt: now, wordCount: 0, calendar: calendar, locale: locale, now: now
        )

        let expectedDay = String(localized: "noteHeader.day.today", bundle: .module, locale: locale)
        let expected = expectedLine(day: expectedDay, time: "15:00", wordCount: 0, locale: locale)

        #expect(result == expected)
    }

    @Test("A une semaine, le nom du jour (comme NoteRelativeDateFormatter) est utilise")
    func withinAWeekUsesWeekdayName() throws {
        let calendar = parisCalendar()
        let locale = Locale(identifier: "fr_FR")
        // 2026-08-10 est un lundi, donc 2026-08-04 est un mardi.
        let now = try makeDate(year: 2026, month: 8, day: 10, hour: 12, calendar: calendar)
        let date = try makeDate(year: 2026, month: 8, day: 4, hour: 9, minute: 12, calendar: calendar)

        let result = NoteHeaderMetadataFormatter.string(
            modifiedAt: date, wordCount: 10, calendar: calendar, locale: locale, now: now
        )

        let style = Date.FormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone).weekday(.wide)
        let expectedDay = date.formatted(style)
        let expected = expectedLine(day: expectedDay, time: "09:12", wordCount: 10, locale: locale)

        #expect(result == expected)
        #expect(expectedDay.localizedCaseInsensitiveContains("mardi"))
    }
}
