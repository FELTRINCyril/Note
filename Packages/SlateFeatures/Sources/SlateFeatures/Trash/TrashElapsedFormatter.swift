import Foundation

/// Libelle "Supprimee il y a N jours" (design P3, artboard B). Fonction PURE au-dessus
/// de `TrashRetentionPolicy.elapsedDays(trashedAt:now:calendar:)`, meme motif que
/// `TrashExpirationFormatter`.
public enum TrashElapsedFormatter {
    /// - `<= 0` (mise a la corbeille aujourd'hui) -> "Supprimee aujourd'hui".
    /// - `1` -> "Supprimee il y a 1 jour" (singulier).
    /// - `>= 2` -> "Supprimee il y a N jours" (pluriel).
    public static func string(elapsedDays: Int, locale: Locale = .autoupdatingCurrent) -> String {
        switch elapsedDays {
        case ..<1:
            return String(localized: "trash.elapsed.today", bundle: .module, locale: locale)
        case 1:
            return String(localized: "trash.elapsed.oneDay", bundle: .module, locale: locale)
        default:
            let template = String(localized: "trash.elapsed.manyDays", bundle: .module, locale: locale)
            return String(format: template, elapsedDays)
        }
    }

    /// Confort : calcule directement `elapsedDays` puis le libelle.
    public static func string(
        trashedAt: Date,
        now: Date,
        calendar: Calendar = .current,
        locale: Locale = .autoupdatingCurrent
    ) -> String {
        string(
            elapsedDays: TrashRetentionPolicy.elapsedDays(trashedAt: trashedAt, now: now, calendar: calendar),
            locale: locale
        )
    }
}
