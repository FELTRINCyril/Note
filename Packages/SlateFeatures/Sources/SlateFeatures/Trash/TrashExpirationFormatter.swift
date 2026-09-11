import Foundation

/// Libelle d'expiration d'une note en corbeille (design P3, artboard B : "expire dans
/// 28 jours" / "expire demain"). Fonction PURE construite au-dessus de
/// `TrashRetentionPolicy.remainingDays(trashedAt:now:calendar:)`, meme motif que
/// `NoteRelativeDateFormatter` (calendar/locale injectes, jamais lus en dur).
public enum TrashExpirationFormatter {
    /// Libelle a partir d'un nombre de jours restants deja calcule (voir
    /// `TrashRetentionPolicy.remainingDays(trashedAt:now:calendar:)`).
    ///
    /// - `< 0` (deja due a la purge, cas defensif) et `0` -> "expire aujourd'hui".
    /// - `1` -> "expire demain" (design P3, "Brouillon newsletter juin").
    /// - `>= 2` -> "expire dans N jours" (design P3, "Ancien plan de lancement").
    public static func string(remainingDays: Int, locale: Locale = .autoupdatingCurrent) -> String {
        switch remainingDays {
        case ..<1:
            return String(localized: "trash.expiration.today", bundle: .module, locale: locale)
        case 1:
            return String(localized: "trash.expiration.tomorrow", bundle: .module, locale: locale)
        default:
            let template = String(localized: "trash.expiration.days", bundle: .module, locale: locale)
            return String(format: template, remainingDays)
        }
    }

    /// Confort : calcule directement `remainingDays` puis le libelle.
    public static func string(
        trashedAt: Date,
        now: Date,
        calendar: Calendar = .current,
        locale: Locale = .autoupdatingCurrent
    ) -> String {
        string(
            remainingDays: TrashRetentionPolicy.remainingDays(trashedAt: trashedAt, now: now, calendar: calendar),
            locale: locale
        )
    }
}
