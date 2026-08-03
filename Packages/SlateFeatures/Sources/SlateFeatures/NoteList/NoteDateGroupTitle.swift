import Foundation

/// Libelle localise d'un `NoteDateGroupKind` (spec E3, en-tetes de regroupement).
/// Separe de `NoteDateGrouper` (qui decide QUELLE note va dans quel groupe) : ce type
/// decide seulement comment NOMMER un groupe une fois determine - deux responsabilites
/// distinctes, chacune testable independamment.
///
/// Les noms de mois et d'annee ne sont JAMAIS ecrits en dur (pas de tableau
/// `["Janvier", "Fevrier", ...]`) : ils passent par `Date.FormatStyle`, qui les
/// localise correctement (FR/EN, et toute autre langue ajoutee plus tard sans code
/// supplementaire). `calendar` et `locale` sont injectes avec les memes valeurs par
/// defaut que `NoteDateGrouper`, pour les memes raisons de determinisme en test.
public enum NoteDateGroupTitle {
    public static func string(
        for kind: NoteDateGroupKind,
        calendar: Calendar = .current,
        locale: Locale = .autoupdatingCurrent
    ) -> String {
        // `locale:` explicite sur CHAQUE branche, y compris les libelles fixes
        // (Aujourd'hui/Hier/...) : cette fonction recoit `locale` en parametre
        // precisement pour rester deterministe en test, la resolution ne doit donc
        // jamais dependre de la locale ambiante du processus - voir
        // `NoteDateGroupTitleTests`.
        switch kind {
        case .today:
            return String(localized: "noteList.dateGroup.today", bundle: .module, locale: locale)
        case .yesterday:
            return String(localized: "noteList.dateGroup.yesterday", bundle: .module, locale: locale)
        case .previous7Days:
            return String(localized: "noteList.dateGroup.previous7Days", bundle: .module, locale: locale)
        case .previous30Days:
            return String(localized: "noteList.dateGroup.previous30Days", bundle: .module, locale: locale)
        case .month(let year, let month):
            let date = firstOfMonth(year: year, month: month, calendar: calendar)
            let style = Date.FormatStyle(locale: locale, calendar: calendar).month(.wide)
            return date.formatted(style)
        case .year(let year):
            let date = firstOfMonth(year: year, month: 1, calendar: calendar)
            let style = Date.FormatStyle(locale: locale, calendar: calendar).year()
            return date.formatted(style)
        }
    }

    /// Construit une date arbitraire (le 1er du mois) representant `year`/`month` dans
    /// `calendar` - seul le mois/l'annee du resultat de `Date.FormatStyle` nous
    /// interesse, le jour exact est sans consequence.
    private static func firstOfMonth(year: Int, month: Int, calendar: Calendar) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = 1
        return calendar.date(from: components) ?? Date(timeIntervalSince1970: 0)
    }
}
