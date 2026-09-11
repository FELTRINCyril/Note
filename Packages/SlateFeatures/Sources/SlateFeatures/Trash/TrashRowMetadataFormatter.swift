import Foundation

/// Compose la ligne de metadonnees d'une ligne de `TrashView` (design P3, artboard B) :
/// "Supprimee il y a 2 jours - etait dans Produit - expire dans 28 jours", ou variante
/// verrouillee "Verrouillee - supprimee il y a 9 jours - expire dans 21 jours" (pas de
/// nom de dossier affiche pour une note verrouillee, meme choix que le design).
///
/// Fonction PURE : ne prend que des valeurs deja extraites du modele (jamais `Note`
/// directement), pour rester testable sans `ModelContext`.
public enum TrashRowMetadataFormatter {
    public static func string(
        isLocked: Bool,
        trashedAt: Date,
        folderName: String?,
        now: Date,
        calendar: Calendar = .current,
        locale: Locale = .autoupdatingCurrent
    ) -> String {
        var parts: [String] = []
        if isLocked {
            parts.append(String(localized: "trash.row.locked", bundle: .module, locale: locale))
        }
        parts.append(TrashElapsedFormatter.string(trashedAt: trashedAt, now: now, calendar: calendar, locale: locale))
        if !isLocked, let folderName {
            let template = String(localized: "trash.row.wasInFolder", bundle: .module, locale: locale)
            parts.append(String(format: template, folderName))
        }
        parts.append(
            TrashExpirationFormatter.string(trashedAt: trashedAt, now: now, calendar: calendar, locale: locale)
        )
        let separator = String(localized: "trash.row.metadataSeparator", bundle: .module, locale: locale)
        return parts.joined(separator: separator)
    }
}
