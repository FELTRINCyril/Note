import Foundation
import Testing
import SlateModel
@testable import SlateFeatures

/// Tests de `NoteDateGrouper` (Phase 4, `docs/04_liste_notes.md`) : cas limites exiges
/// explicitement par Cyril - minuit, changement de mois, changement d'annee, fuseau
/// horaire - plus les deux bords de "7 jours" et "30 jours", l'ordre des groupes, et le
/// fait que le regroupement ne re-trie jamais.
///
/// Chaque test construit son propre `Calendar` (souvent avec un `TimeZone` explicite)
/// et son propre `now`, jamais `Calendar.current`/`Date.now` : c'est la condition de
/// determinisme exigee par la documentation de `NoteDateGrouper`.
@Suite("NoteDateGrouper")
struct NoteDateGrouperTests {
    private func parisCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Paris") ?? .current
        return calendar
    }

    private func makeNote(title: String, modifiedAt: Date) -> Note {
        Note(title: title, modifiedAt: modifiedAt)
    }

    private func groupKinds(
        notes: [Note],
        calendar: Calendar,
        now: Date
    ) -> [NoteDateGroupKind] {
        NoteDateGrouper.group(notes: notes, referenceDate: \.modifiedAt, calendar: calendar, now: now).map(\.kind)
    }

    // MARK: - Minuit

    @Test("Une note a 23h59 hier et une note a 00h01 aujourd'hui tombent dans des groupes distincts")
    func midnightBoundarySeparatesYesterdayFromToday() throws {
        let calendar = parisCalendar()
        // now : 3 aout 2026, 10h00 Paris.
        let now = try makeDate(year: 2026, month: 8, day: 3, hour: 10, calendar: calendar)
        let justBeforeMidnight = try makeDate(year: 2026, month: 8, day: 2, hour: 23, minute: 59, calendar: calendar)
        let justAfterMidnight = try makeDate(year: 2026, month: 8, day: 3, hour: 0, minute: 1, calendar: calendar)

        let notes = [makeNote(title: "Hier tard", modifiedAt: justBeforeMidnight),
                     makeNote(title: "Aujourd'hui tot", modifiedAt: justAfterMidnight)]

        let groups = NoteDateGrouper.group(notes: notes, referenceDate: \.modifiedAt, calendar: calendar, now: now)

        let todayGroup = try requireGroup(groups, kind: .today)
        let yesterdayGroup = try requireGroup(groups, kind: .yesterday)
        #expect(todayGroup.notes.map(\.title) == ["Aujourd'hui tot"])
        #expect(yesterdayGroup.notes.map(\.title) == ["Hier tard"])
    }

    @Test("Une note exactement a minuit aujourd'hui est dans le groupe Aujourd'hui")
    func exactlyMidnightTodayIsInTodayGroup() throws {
        let calendar = parisCalendar()
        let now = try makeDate(year: 2026, month: 8, day: 3, hour: 10, calendar: calendar)
        let exactlyMidnight = try makeDate(year: 2026, month: 8, day: 3, hour: 0, minute: 0, calendar: calendar)

        let notes = [makeNote(title: "Minuit", modifiedAt: exactlyMidnight)]
        let kinds = groupKinds(notes: notes, calendar: calendar, now: now)

        #expect(kinds == [.today])
    }

    // MARK: - Bords de "7 jours precedents"

    @Test("J-2 tombe dans previous7Days, J-1 dans yesterday : la frontiere est nette")
    func twoDaysAgoIsPrevious7DaysNotYesterday() throws {
        let calendar = parisCalendar()
        let now = try makeDate(year: 2026, month: 8, day: 10, hour: 12, calendar: calendar)
        let twoDaysAgo = try makeDate(year: 2026, month: 8, day: 8, hour: 12, calendar: calendar)

        let kinds = groupKinds(notes: [makeNote(title: "J-2", modifiedAt: twoDaysAgo)], calendar: calendar, now: now)
        #expect(kinds == [.previous7Days])
    }

    @Test("J-7 est le dernier jour de previous7Days")
    func sevenDaysAgoIsLastDayOfPrevious7Days() throws {
        let calendar = parisCalendar()
        let now = try makeDate(year: 2026, month: 8, day: 10, hour: 12, calendar: calendar)
        let sevenDaysAgo = try makeDate(year: 2026, month: 8, day: 3, hour: 12, calendar: calendar)

        let kinds = groupKinds(notes: [makeNote(title: "J-7", modifiedAt: sevenDaysAgo)], calendar: calendar, now: now)
        #expect(kinds == [.previous7Days])
    }

    @Test("J-8 bascule dans previous30Days, pas previous7Days")
    func eightDaysAgoIsPrevious30DaysNotPrevious7Days() throws {
        let calendar = parisCalendar()
        let now = try makeDate(year: 2026, month: 8, day: 10, hour: 12, calendar: calendar)
        let eightDaysAgo = try makeDate(year: 2026, month: 8, day: 2, hour: 12, calendar: calendar)

        let kinds = groupKinds(notes: [makeNote(title: "J-8", modifiedAt: eightDaysAgo)], calendar: calendar, now: now)
        #expect(kinds == [.previous30Days])
    }

    // MARK: - Bords de "30 jours precedents"

    @Test("J-30 est le dernier jour de previous30Days")
    func thirtyDaysAgoIsLastDayOfPrevious30Days() throws {
        let calendar = parisCalendar()
        let now = try makeDate(year: 2026, month: 8, day: 31, hour: 12, calendar: calendar)
        let thirtyDaysAgo = try makeDate(year: 2026, month: 8, day: 1, hour: 12, calendar: calendar)

        let note = makeNote(title: "J-30", modifiedAt: thirtyDaysAgo)
        #expect(groupKinds(notes: [note], calendar: calendar, now: now) == [.previous30Days])
    }

    @Test("J-31 bascule vers un groupe mois/annee, pas previous30Days")
    func thirtyOneDaysAgoFallsBackToMonthGroup() throws {
        let calendar = parisCalendar()
        let now = try makeDate(year: 2026, month: 8, day: 31, hour: 12, calendar: calendar)
        let thirtyOneDaysAgo = try makeDate(year: 2026, month: 7, day: 31, hour: 12, calendar: calendar)

        let note = makeNote(title: "J-31", modifiedAt: thirtyOneDaysAgo)
        #expect(groupKinds(notes: [note], calendar: calendar, now: now) == [.month(year: 2026, month: 7)])
    }

    // MARK: - Changement de mois

    @Test("Deux mois differents de l'annee en cours produisent deux groupes mois, du plus recent au plus ancien")
    func differentMonthsOfCurrentYearProduceDescendingMonthGroups() throws {
        let calendar = parisCalendar()
        let now = try makeDate(year: 2026, month: 8, day: 31, hour: 12, calendar: calendar)
        let march = try makeDate(year: 2026, month: 3, day: 3, hour: 12, calendar: calendar)
        let january = try makeDate(year: 2026, month: 1, day: 15, hour: 12, calendar: calendar)

        let notes = [makeNote(title: "Mars", modifiedAt: march), makeNote(title: "Janvier", modifiedAt: january)]
        let kinds = groupKinds(notes: notes, calendar: calendar, now: now)

        #expect(kinds == [.month(year: 2026, month: 3), .month(year: 2026, month: 1)])
    }

    // MARK: - Changement d'annee

    @Test("Une note de l'annee en cours au-dela de 30 jours produit un groupe mois, une note passee un groupe annee")
    func currentYearProducesMonthGroupPastYearProducesYearGroup() throws {
        let calendar = parisCalendar()
        let now = try makeDate(year: 2026, month: 6, day: 15, hour: 12, calendar: calendar)
        let earlierThisYear = try makeDate(year: 2026, month: 3, day: 1, hour: 12, calendar: calendar)
        let lastYear = try makeDate(year: 2025, month: 11, day: 18, hour: 12, calendar: calendar)

        let notes = [
            makeNote(title: "Cette annee", modifiedAt: earlierThisYear),
            makeNote(title: "Annee passee", modifiedAt: lastYear)
        ]
        let kinds = groupKinds(notes: notes, calendar: calendar, now: now)

        #expect(kinds == [.month(year: 2026, month: 3), .year(2025)])
    }

    @Test("Plusieurs annees passees produisent des groupes annee tries par annee decroissante")
    func multiplePastYearsAreOrderedDescending() throws {
        let calendar = parisCalendar()
        let now = try makeDate(year: 2026, month: 8, day: 31, hour: 12, calendar: calendar)
        let year2024 = try makeDate(year: 2024, month: 5, day: 1, hour: 12, calendar: calendar)
        let year2023 = try makeDate(year: 2023, month: 5, day: 1, hour: 12, calendar: calendar)
        let year2025 = try makeDate(year: 2025, month: 5, day: 1, hour: 12, calendar: calendar)

        let notes = [
            makeNote(title: "2024", modifiedAt: year2024),
            makeNote(title: "2023", modifiedAt: year2023),
            makeNote(title: "2025", modifiedAt: year2025)
        ]
        let kinds = groupKinds(notes: notes, calendar: calendar, now: now)

        #expect(kinds == [.year(2025), .year(2024), .year(2023)])
    }

    // MARK: - Fuseau horaire

    @Test("Le meme instant tombe dans des jours calendaires differents selon le fuseau horaire injecte")
    func sameInstantFallsInDifferentCalendarDaysDependingOnInjectedTimeZone() throws {
        // 2026-08-03 12:00 UTC : 3 aout 14h00 a Paris (UTC+2 en ete), mais deja 4 aout
        // 02h00 a Kiritimati (UTC+14) - un cas de fuseau a decalage superieur a 12h,
        // choisi precisement pour eviter tout doute sur un simple "avant/apres minuit
        // UTC" trivial. Verifie independamment via Python/zoneinfo avant d'ecrire ce
        // test (memes resultats : Paris = 3 aout, Kiritimati = 4 aout).
        let instant = Date(timeIntervalSince1970: 1_785_758_400) // 2026-08-03T12:00:00Z

        var paris = Calendar(identifier: .gregorian)
        paris.timeZone = TimeZone(identifier: "Europe/Paris") ?? .current
        var kiritimati = Calendar(identifier: .gregorian)
        kiritimati.timeZone = TimeZone(identifier: "Pacific/Kiritimati") ?? .current

        // `now` choisi comme le lendemain matin, dans les deux calendriers, pour que
        // l'instant reste "hier" (jamais "aujourd'hui") des deux points de vue - seule
        // la VALEUR du jour differe, pas le fait qu'il s'agisse d'hier.
        let nowParis = try makeDate(year: 2026, month: 8, day: 4, hour: 8, calendar: paris)
        let nowKiritimati = try makeDate(year: 2026, month: 8, day: 5, hour: 8, calendar: kiritimati)

        let noteParis = makeNote(title: "Instant", modifiedAt: instant)
        let noteKiritimati = makeNote(title: "Instant", modifiedAt: instant)

        let parisKinds = groupKinds(notes: [noteParis], calendar: paris, now: nowParis)
        let kiritimatiKinds = groupKinds(notes: [noteKiritimati], calendar: kiritimati, now: nowKiritimati)

        #expect(parisKinds == [.yesterday])
        #expect(kiritimatiKinds == [.yesterday])
    }

    @Test(
        "Pour un MEME couple (note, now) fige, deux fuseaux produisent des groupes differents"
    )
    func sameFixedNowProducesDifferentGroupsAcrossTimeZones() throws {
        // La faiblesse du test precedent est de choisir un `now` DIFFERENT par fuseau
        // (recale pour que le resultat reste "hier" des deux cotes) : ca prouve que le
        // jour calendaire differe (voir le commentaire de l'autre test), mais pas que
        // cette difference change le GROUPE produit par le regroupeur pour un `now`
        // partage. Ici `note` et `now` sont deux instants UTC FIXES et IDENTIQUES pour
        // les deux calendriers ; seul le fuseau injecte change.
        //
        // note = 2026-08-03T22:00:00Z, now = 2026-08-04T02:00:00Z (4h plus tard, meme
        // instant absolu pour les deux zones). Verifie independamment (Python/zoneinfo) :
        // - UTC (offset 0) : note locale = 3 aout 22h00, now locale = 4 aout 02h00 ->
        //   jours calendaires DIFFERENTS -> deltaDays = 1 -> .yesterday.
        // - Asia/Vladivostok (UTC+10, sans heure d'ete en aout) : note locale = 4 aout
        //   08h00, now locale = 4 aout 12h00 -> MEME jour calendaire -> deltaDays = 0
        //   -> .today.
        // Le decalage horaire (+10h) fait glisser les DEUX instants au-dela de minuit
        // local, du meme cote de la frontiere de jour : c'est exactement le mecanisme
        // par lequel un fuseau horaire change le groupe attribue a un instant fige.
        let note = Date(timeIntervalSince1970: 1_785_794_400) // 2026-08-03T22:00:00Z
        let now = Date(timeIntervalSince1970: 1_785_808_800) // 2026-08-04T02:00:00Z

        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = try require(TimeZone(identifier: "UTC"))
        var vladivostok = Calendar(identifier: .gregorian)
        vladivostok.timeZone = try require(TimeZone(identifier: "Asia/Vladivostok"))

        let utcKinds = groupKinds(notes: [makeNote(title: "Fixe", modifiedAt: note)], calendar: utc, now: now)
        let vladivostokKinds = groupKinds(
            notes: [makeNote(title: "Fixe", modifiedAt: note)], calendar: vladivostok, now: now
        )

        #expect(utcKinds == [.yesterday])
        #expect(vladivostokKinds == [.today])
    }

    // MARK: - Note du futur

    @Test("Une note modifiee apres 'now' (horloge desynchronisee) tombe dans Aujourd'hui, pas dans un groupe absurde")
    func futureModifiedDateFallsIntoTodayNotYesterdayOrAnEmptyGroup() throws {
        let calendar = parisCalendar()
        let now = try makeDate(year: 2026, month: 8, day: 3, hour: 10, calendar: calendar)
        let inTheFuture = try makeDate(year: 2026, month: 8, day: 5, hour: 10, calendar: calendar)

        let kinds = groupKinds(
            notes: [makeNote(title: "Resynchronisation CloudKit", modifiedAt: inTheFuture)],
            calendar: calendar,
            now: now
        )

        #expect(kinds == [.today])
    }

    // MARK: - Passage a l'annee suivante

    @Test("Une note de decembre vue en janvier tombe dans le groupe annee, jamais dans le groupe mois en cours")
    func decemberNoteViewedInJanuaryFallsIntoYearGroupNotCurrentYearMonthGroup() throws {
        let calendar = parisCalendar()
        let now = try makeDate(year: 2026, month: 1, day: 15, hour: 10, calendar: calendar)
        // Volontairement a plus de 30 jours de `now` (45 jours) : au-dela de 30 jours,
        // c'est l'annee de la note (2025, differente de l'annee en cours 2026) qui
        // decide du groupe, jamais un delta en jours a lui seul - voir la doc de tete de
        // `NoteDateGrouper` ("l'annee en cours prime sur deltaDays").
        let lastDecember = try makeDate(year: 2025, month: 12, day: 1, hour: 10, calendar: calendar)

        let kinds = groupKinds(
            notes: [makeNote(title: "Bilan annuel", modifiedAt: lastDecember)],
            calendar: calendar,
            now: now
        )

        #expect(kinds == [.year(2025)])
    }

    // MARK: - Regroupement ne re-trie jamais

    @Test("L'ordre des notes a l'interieur d'un groupe reprend exactement l'ordre en entree")
    func groupingPreservesInputOrderWithinAGroup() throws {
        let calendar = parisCalendar()
        let now = try makeDate(year: 2026, month: 8, day: 3, hour: 12, calendar: calendar)

        // Deliberement dans le "mauvais" ordre alphabetique pour prouver qu'aucun tri
        // implicite n'est applique par le regroupement.
        let notes = [
            makeNote(title: "Zebre", modifiedAt: now),
            makeNote(title: "Alpha", modifiedAt: now),
            makeNote(title: "Milieu", modifiedAt: now)
        ]

        let groups = NoteDateGrouper.group(notes: notes, referenceDate: \.modifiedAt, calendar: calendar, now: now)
        #expect(groups.first?.notes.map(\.title) == ["Zebre", "Alpha", "Milieu"])
    }

    // MARK: - Le critere de tri choisi change la date de reference

    @Test("referenceDate permet de grouper sur createdAt plutot que modifiedAt")
    func referenceDateClosureAllowsGroupingByCreatedDate() throws {
        let calendar = parisCalendar()
        let now = try makeDate(year: 2026, month: 8, day: 3, hour: 12, calendar: calendar)
        let createdLongAgo = try makeDate(year: 2025, month: 1, day: 1, hour: 12, calendar: calendar)

        let note = Note(title: "Vieille creation, modif recente", createdAt: createdLongAgo, modifiedAt: now)

        let groupedByModified = NoteDateGrouper.group(
            notes: [note], referenceDate: \.modifiedAt, calendar: calendar, now: now
        )
        let groupedByCreated = NoteDateGrouper.group(
            notes: [note], referenceDate: \.createdAt, calendar: calendar, now: now
        )

        #expect(groupedByModified.map(\.kind) == [.today])
        #expect(groupedByCreated.map(\.kind) == [.year(2025)])
    }

    // MARK: - Helpers

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
        return try require(calendar.date(from: components))
    }

    private func requireGroup(_ groups: [NoteDateGroup], kind: NoteDateGroupKind) throws -> NoteDateGroup {
        try require(groups.first { $0.kind == kind })
    }

    private func require<T>(_ value: T?) throws -> T {
        try #require(value)
    }
}
