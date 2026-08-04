import Foundation
import Testing
@testable import SlateFeatures

/// Tests de la cascade de `NoteRelativeDateFormatter` (spec E3 : "14:22" ->
/// "Hier 09:10" -> "Lundi" -> "14 juil." -> "18 nov. 2025"). `calendar`/`now`/`locale`
/// sont toujours injectes explicitement, jamais lus depuis l'environnement reel - meme
/// exigence de determinisme que `NoteDateGrouperTests`.
@Suite("NoteRelativeDateFormatter")
struct NoteRelativeDateFormatterTests {
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

    @Test("Aujourd'hui affiche l'heure seule")
    func todayShowsTimeOnly() throws {
        let calendar = parisCalendar()
        let now = try makeDate(year: 2026, month: 8, day: 3, hour: 15, calendar: calendar)
        let date = try makeDate(year: 2026, month: 8, day: 3, hour: 14, minute: 22, calendar: calendar)

        let result = NoteRelativeDateFormatter.string(
            for: date,
            calendar: calendar,
            locale: Locale(identifier: "fr_FR"),
            now: now
        )

        #expect(result.contains("14"))
        #expect(result.contains("22"))
        #expect(!result.contains("Hier"))
    }

    @Test("Hier compose le gabarit localise 'yesterday' avec l'heure formatee")
    func yesterdayComposesLocalizedTemplateWithTime() throws {
        let calendar = parisCalendar()
        let locale = Locale(identifier: "fr_FR")
        let now = try makeDate(year: 2026, month: 8, day: 3, hour: 15, calendar: calendar)
        let date = try makeDate(year: 2026, month: 8, day: 2, hour: 9, minute: 10, calendar: calendar)

        let result = NoteRelativeDateFormatter.string(for: date, calendar: calendar, locale: locale, now: now)

        // Reconstruit la composition attendue avec les MEMES primitives que
        // l'implementation (gabarit localise "noteList.cell.date.yesterday" + heure
        // formatee) plutot que de figer un texte traduit en dur dans ce test : robuste
        // a une re-traduction future, et surtout independant d'un constat fait en
        // ecrivant cette phase - `swift test` en CLI, contrairement a `xcodebuild`, ne
        // compile pas ici `Localizable.xcstrings` pour le bundle de test, meme pour des
        // cles bien plus anciennes que cette phase (verifie avec "action.cancel", deja
        // presente avant la Phase 4) : `String(localized:bundle:)` y retombe sur la cle
        // brute. C'est un constat d'environnement a signaler, pas un defaut de cette
        // fonction - comparer aux memes primitives garde ce test valable dans les deux
        // cas (String Catalog compile ou non).
        let template = String(localized: "noteList.cell.date.yesterday", bundle: .module, locale: locale)
        let timeOnly = NoteRelativeDateFormatter.string(for: date, calendar: calendar, locale: locale, now: date)
        let expected = String(format: template, timeOnly)

        #expect(result == expected)
        // La branche "hier" doit rester DISTINCTE de la branche "aujourd'hui" (heure
        // seule) : `timeOnly` (calcule ci-dessus via `Date.FormatStyle`, jamais affecte
        // par le constat ci-dessus) prouve que le gabarit a bien ete applique.
        #expect(result != timeOnly)
    }

    @Test("J-6 (dans la semaine) affiche le nom du jour, sans heure")
    func sixDaysAgoShowsWeekdayNameOnly() throws {
        let calendar = parisCalendar()
        // 2026-08-10 est un lundi.
        let now = try makeDate(year: 2026, month: 8, day: 10, hour: 12, calendar: calendar)
        let date = try makeDate(year: 2026, month: 8, day: 4, hour: 9, calendar: calendar)

        let result = NoteRelativeDateFormatter.string(
            for: date,
            calendar: calendar,
            locale: Locale(identifier: "fr_FR"),
            now: now
        )

        #expect(result.localizedCaseInsensitiveContains("mardi"))
        #expect(!result.contains(":"))
    }

    /// Arbitrage de Cyril en fin de phase 4 : la borne du formateur est ALIGNEE sur
    /// celle du groupeur (J-7 inclus). Avant, J-7 basculait sur "3 aout" alors que la
    /// note restait dans le groupe "7 jours precedents" avec des voisines affichant un
    /// nom de jour : l'incoherence se voyait. Ce test verrouille l'alignement.
    @Test("J-7, derniere borne du groupe 7 jours, affiche encore le nom du jour")
    func sevenDaysAgoStillShowsWeekdayNameToMatchItsDateGroup() throws {
        let calendar = parisCalendar()
        // 2026-08-10 est un lundi, donc 2026-08-03 est le lundi precedent.
        let now = try makeDate(year: 2026, month: 8, day: 10, hour: 12, calendar: calendar)
        let date = try makeDate(year: 2026, month: 8, day: 3, hour: 9, calendar: calendar)

        let result = NoteRelativeDateFormatter.string(
            for: date,
            calendar: calendar,
            locale: Locale(identifier: "fr_FR"),
            now: now
        )

        #expect(result.localizedCaseInsensitiveContains("lundi"))
        #expect(!result.contains(":"))
    }

    /// La bascule vers une date explicite se fait donc a J-8, premier jour qui n'est
    /// plus dans le groupe "7 jours precedents" du `NoteDateGrouper`.
    @Test("J-8, premier jour hors du groupe 7 jours, bascule sur jour+mois")
    func eightDaysAgoShowsDayAndMonthNotWeekday() throws {
        let calendar = parisCalendar()
        let now = try makeDate(year: 2026, month: 8, day: 10, hour: 12, calendar: calendar)
        let date = try makeDate(year: 2026, month: 8, day: 2, hour: 9, calendar: calendar)

        let result = NoteRelativeDateFormatter.string(
            for: date,
            calendar: calendar,
            locale: Locale(identifier: "fr_FR"),
            now: now
        )

        #expect(result.contains("2"))
        #expect(!result.contains(":"))
        // Pas un nom de jour de semaine : verifie l'absence des jours francais usuels.
        for weekday in ["lundi", "mardi", "mercredi", "jeudi", "vendredi", "samedi", "dimanche"] {
            #expect(!result.localizedCaseInsensitiveContains(weekday))
        }
    }

    @Test("Meme annee, au-dela d'une semaine : jour + mois abrege, sans annee")
    func withinCurrentYearShowsDayAndMonthWithoutYear() throws {
        let calendar = parisCalendar()
        let now = try makeDate(year: 2026, month: 8, day: 3, hour: 12, calendar: calendar)
        let date = try makeDate(year: 2026, month: 7, day: 14, hour: 9, calendar: calendar)

        let result = NoteRelativeDateFormatter.string(
            for: date,
            calendar: calendar,
            locale: Locale(identifier: "fr_FR"),
            now: now
        )

        #expect(result.contains("14"))
        #expect(!result.contains("2026"))
    }

    @Test("Annee differente : jour + mois abrege + annee")
    func differentYearShowsDayMonthAndYear() throws {
        let calendar = parisCalendar()
        let now = try makeDate(year: 2026, month: 8, day: 3, hour: 12, calendar: calendar)
        let date = try makeDate(year: 2025, month: 11, day: 18, hour: 9, calendar: calendar)

        let result = NoteRelativeDateFormatter.string(
            for: date,
            calendar: calendar,
            locale: Locale(identifier: "fr_FR"),
            now: now
        )

        #expect(result.contains("18"))
        #expect(result.contains("2025"))
    }

    @Test("Le fuseau horaire injecte change le jour calendaire, donc le format retenu")
    func timeZoneChangesTheResolvedFormat() throws {
        // 2026-08-03 12:00 UTC : 3 aout a Paris, deja 4 aout a Kiritimati (voir
        // NoteDateGrouperTests pour la verification independante de ces horaires).
        let instant = Date(timeIntervalSince1970: 1_785_758_400)

        var paris = Calendar(identifier: .gregorian)
        paris.timeZone = TimeZone(identifier: "Europe/Paris") ?? .current
        var kiritimati = Calendar(identifier: .gregorian)
        kiritimati.timeZone = TimeZone(identifier: "Pacific/Kiritimati") ?? .current

        let nowParis = try makeDate(year: 2026, month: 8, day: 3, hour: 20, calendar: paris)
        let nowKiritimati = try makeDate(year: 2026, month: 8, day: 4, hour: 20, calendar: kiritimati)

        let resultParis = NoteRelativeDateFormatter.string(
            for: instant, calendar: paris, locale: Locale(identifier: "fr_FR"), now: nowParis
        )
        let resultKiritimati = NoteRelativeDateFormatter.string(
            for: instant, calendar: kiritimati, locale: Locale(identifier: "fr_FR"), now: nowKiritimati
        )

        // Meme instant, meme "aujourd'hui" relatif dans les deux fuseaux (l'heure
        // seule est affichee des deux cotes), mais l'heure AFFICHEE differe forcement
        // puisque l'heure locale differe (14h a Paris, 2h a Kiritimati).
        #expect(resultParis != resultKiritimati)
    }
}
