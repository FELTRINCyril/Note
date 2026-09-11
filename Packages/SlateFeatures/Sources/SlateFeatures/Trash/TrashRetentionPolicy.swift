import Foundation

/// Regle de purge automatique de la corbeille (`docs/11_organisation_notes.md` :
/// "purge auto apres N jours (ex. 30)") et calcul PUR du temps restant avant
/// expiration d'une note mise a la corbeille.
///
/// Deliberement independant de `NoteActionsProviding` : ce n'est qu'une projection de
/// `Note.trashedAt` (deja porte par `SlateModel`, pose avant cette phase), calculable
/// et testable sans aucun service - voir `NoteActionsProviding.swift`.
public enum TrashRetentionPolicy {
    /// Nombre de jours qu'une note reste en corbeille avant suppression definitive
    /// automatique (design P3 : "supprimees definitivement au bout de 30 jours").
    public static let retentionDays = 30

    /// Date a laquelle `trashedAt` expirera (suppression definitive automatique).
    public static func expirationDate(trashedAt: Date, calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: .day, value: retentionDays, to: trashedAt) ?? trashedAt
    }

    /// Nombre de jours CALENDAIRES restants avant expiration, a la date `now`. Meme
    /// convention que `NoteDateGrouper`/`NoteRelativeDateFormatter` : comparaison sur le
    /// debut de journee de chaque date, jamais en secondes brutes (insensible au
    /// changement d'heure ete/hiver). Peut etre negatif si `now` a deja depasse
    /// l'expiration (note qui aurait du etre purgee mais que la purge automatique n'a
    /// pas encore traitee).
    public static func remainingDays(trashedAt: Date, now: Date, calendar: Calendar = .current) -> Int {
        let expiration = expirationDate(trashedAt: trashedAt, calendar: calendar)
        let startOfNow = calendar.startOfDay(for: now)
        let startOfExpiration = calendar.startOfDay(for: expiration)
        return calendar.dateComponents([.day], from: startOfNow, to: startOfExpiration).day ?? 0
    }

    /// Nombre de jours CALENDAIRES ecoules depuis la mise a la corbeille, a la date
    /// `now`. Meme convention de calcul que `remainingDays(trashedAt:now:calendar:)`.
    public static func elapsedDays(trashedAt: Date, now: Date, calendar: Calendar = .current) -> Int {
        let startOfTrashedAt = calendar.startOfDay(for: trashedAt)
        let startOfNow = calendar.startOfDay(for: now)
        return calendar.dateComponents([.day], from: startOfTrashedAt, to: startOfNow).day ?? 0
    }

    /// Vrai si une note mise a la corbeille a `trashedAt` a deja depasse sa date
    /// d'expiration a `now` - sert a `TrashView` pour ne jamais afficher une note deja
    /// due a la purge (defensif : la purge automatique reelle est hors du perimetre de
    /// cet agent, voir `NoteActionsProviding.purgeExpiredTrash(now:)`).
    public static func isExpired(trashedAt: Date, now: Date, calendar: Calendar = .current) -> Bool {
        remainingDays(trashedAt: trashedAt, now: now, calendar: calendar) < 0
    }
}
