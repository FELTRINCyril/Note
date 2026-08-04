import Foundation

/// Ligne de metadonnees de l'en-tete d'une note (spec E4 : "Modifiee aujourd'hui a
/// 14:22 - 428 mots"). Fonction PURE et testable, meme discipline de determinisme que
/// `NoteRelativeDateFormatter` (`calendar`/`locale`/`now` injectes, jamais lus en dur).
///
/// ## Pourquoi pas `NoteRelativeDateFormatter`
/// Ce formateur existant (Phase 4, liste de notes) produit UNE cascade ou le jour et
/// l'heure ne sont jamais montres ensemble (soit l'heure seule aujourd'hui, soit un nom
/// de jour seul a J-2..J-7, jamais les deux). La spec E4 demande au contraire TOUJOURS
/// "<jour> a <heure>" dans l'en-tete de note. Dupliquer sa cascade avec une regle de
/// composition differente aurait complique sa propre lecture ; ce type reste donc
/// separe, avec sa cascade de jour propre (aujourd'hui/hier/nom du jour/date).
///
/// Le compte de mots n'est PAS calcule ici : `SlateEditor.WordCounter` en est
/// responsable (a partir de `Note.plainText`), ce formateur ne fait que composer la
/// phrase finale a partir d'un compte deja calcule par l'appelant.
public enum NoteHeaderMetadataFormatter {
    public static func string(
        modifiedAt date: Date,
        wordCount: Int,
        calendar: Calendar = .current,
        locale: Locale = .autoupdatingCurrent,
        now: Date = .now
    ) -> String {
        let dayPhrase = dayPhrase(for: date, calendar: calendar, locale: locale, now: now)
        let time = timeString(date, calendar: calendar, locale: locale)
        let wordsPart = wordCountPhrase(wordCount, locale: locale)

        let template = String(localized: "noteHeader.metadataLine", bundle: .module, locale: locale)
        return String(format: template, dayPhrase, time, wordsPart)
    }

    private static func dayPhrase(for date: Date, calendar: Calendar, locale: Locale, now: Date) -> String {
        let startOfToday = calendar.startOfDay(for: now)
        let startOfDate = calendar.startOfDay(for: date)
        let deltaDays = calendar.dateComponents([.day], from: startOfDate, to: startOfToday).day ?? 0

        if deltaDays <= 0 {
            return String(localized: "noteHeader.day.today", bundle: .module, locale: locale)
        }
        if deltaDays == 1 {
            return String(localized: "noteHeader.day.yesterday", bundle: .module, locale: locale)
        }
        if deltaDays <= 7 {
            let style = Date.FormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone)
                .weekday(.wide)
            return date.formatted(style)
        }
        if calendar.component(.year, from: date) == calendar.component(.year, from: now) {
            let style = Date.FormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone)
                .day().month(.abbreviated)
            return date.formatted(style)
        }
        let style = Date.FormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone)
            .day().month(.abbreviated).year()
        return date.formatted(style)
    }

    private static func timeString(_ date: Date, calendar: Calendar, locale: Locale) -> String {
        let style = Date.FormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone)
            .hour().minute()
        return date.formatted(style)
    }

    private static func wordCountPhrase(_ wordCount: Int, locale: Locale) -> String {
        if wordCount == 1 {
            return String(localized: "noteHeader.wordCount.singular", bundle: .module, locale: locale)
        }
        let template = String(localized: "noteHeader.wordCount.plural", bundle: .module, locale: locale)
        return String(format: template, wordCount)
    }
}
