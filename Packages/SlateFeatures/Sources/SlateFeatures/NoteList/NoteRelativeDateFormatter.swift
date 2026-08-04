import Foundation

/// Date relative affichee dans une cellule de la liste de notes (spec E3, "Date :
/// caption 12 - relative : '14:22' -> 'Hier 09:10' -> 'Lundi' -> '14 juil.' -> '18 nov.
/// 2025'"). Fonction PURE et testable, avec la meme exigence de determinisme que
/// `NoteDateGrouper` : `calendar` et `now` sont des parametres injectes, jamais
/// `Calendar.current`/`Date.now` lus en dur a l'interieur.
///
/// ## Cascade et bornes exactes retenues
///
/// `deltaDays` est l'ecart en jours calendaires entre le debut du jour de `date` et le
/// debut du jour de `now` (meme calcul que `NoteDateGrouper`, jamais en secondes - voir
/// sa documentation sur l'heure d'ete).
///
/// - `deltaDays <= 0` (aujourd'hui, ou une note "du futur" par securite) -> heure seule
///   ("14:22").
/// - `deltaDays == 1` -> "Hier" + heure ("Hier 09:10").
/// - `deltaDays` dans `2...7` -> nom du jour de la semaine seul ("Lundi"). Cette borne
///   est ALIGNEE sur `NoteDateGrouper.previous7Days`, qui va aussi jusqu'a J-7 inclus :
///   arbitrage de Cyril en fin de phase 4. Une borne a J-6 laissait la derniere note du
///   groupe "7 jours precedents" afficher une date jour+mois ("27 juil.") alors que
///   toutes ses voisines du meme groupe affichaient un nom de jour ("Lundi"), ce qui se
///   voyait. L'uniformite du groupe primait sur la levee d'ambiguite du nom de jour.
///   Toute evolution de la borne du groupeur doit etre repercutee ici.
/// - `deltaDays >= 8` et meme annee que `now` -> jour + mois abrege ("14 juil.").
/// - sinon (annee differente) -> jour + mois abrege + annee ("18 nov. 2025").
public enum NoteRelativeDateFormatter {
    public static func string(
        for date: Date,
        calendar: Calendar = .current,
        locale: Locale = .autoupdatingCurrent,
        now: Date = .now
    ) -> String {
        let startOfToday = calendar.startOfDay(for: now)
        let startOfDate = calendar.startOfDay(for: date)
        let deltaDays = calendar.dateComponents([.day], from: startOfDate, to: startOfToday).day ?? 0

        if deltaDays <= 0 {
            return timeString(date, calendar: calendar, locale: locale)
        }
        if deltaDays == 1 {
            // `locale:` explicite (pas seulement `bundle:`) : cette fonction recoit
            // `locale` en parametre precisement pour rester deterministe en test, la
            // resolution de cette chaine ne doit donc jamais dependre de la locale
            // ambiante du processus - voir `NoteRelativeDateFormatterTests`.
            let template = String(localized: "noteList.cell.date.yesterday", bundle: .module, locale: locale)
            return String(format: template, timeString(date, calendar: calendar, locale: locale))
        }
        if deltaDays <= 7 {
            return weekdayString(date, calendar: calendar, locale: locale)
        }
        if calendar.component(.year, from: date) == calendar.component(.year, from: now) {
            return dayMonthString(date, calendar: calendar, locale: locale)
        }
        return dayMonthYearString(date, calendar: calendar, locale: locale)
    }

    private static func timeString(_ date: Date, calendar: Calendar, locale: Locale) -> String {
        let style = Date.FormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone)
            .hour().minute()
        return date.formatted(style)
    }

    private static func weekdayString(_ date: Date, calendar: Calendar, locale: Locale) -> String {
        let style = Date.FormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone)
            .weekday(.wide)
        return date.formatted(style)
    }

    private static func dayMonthString(_ date: Date, calendar: Calendar, locale: Locale) -> String {
        let style = Date.FormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone)
            .day().month(.abbreviated)
        return date.formatted(style)
    }

    private static func dayMonthYearString(_ date: Date, calendar: Calendar, locale: Locale) -> String {
        let style = Date.FormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone)
            .day().month(.abbreviated).year()
        return date.formatted(style)
    }
}
