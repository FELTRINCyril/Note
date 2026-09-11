import Foundation

/// Libelles COMPTES du menu contextuel de note en selection multiple (design P3,
/// artboard A : "les libelles se comptent (Mettre 3 notes a la corbeille)").
/// Fonctions PURES, sans dependance a `Note`/SwiftData : uniquement testables sur un
/// entier, comme `FolderRow.folderNoteCountAccessibilityLabel`. `locale` toujours
/// injecte explicitement (jamais lu depuis l'environnement reel a l'interieur), meme
/// exigence de determinisme que `NoteHeaderMetadataFormatter`/`NoteRelativeDateFormatter`.
public enum NoteSelectionActionLabels {
    /// En-tete du menu contextuel en selection multiple ("3 notes selectionnees").
    /// N'est affiche par l'appelant que si `count > 1` (voir `NoteContextMenuContent`) :
    /// cette fonction ne gere donc que le pluriel, mais reste definie pour tout `count`
    /// par simplicite/coherence avec les autres libelles de ce type.
    public static func selectionHeader(count: Int, locale: Locale = .autoupdatingCurrent) -> String {
        if count == 1 {
            return String(localized: "noteList.contextMenu.selectionHeader.one", bundle: .module, locale: locale)
        }
        let template = String(localized: "noteList.contextMenu.selectionHeader.many", bundle: .module, locale: locale)
        return String(format: template, count)
    }

    /// "Mettre a la corbeille" (1) / "Mettre N notes a la corbeille" (N > 1).
    public static func moveToTrash(count: Int, locale: Locale = .autoupdatingCurrent) -> String {
        if count == 1 {
            return String(localized: "noteList.contextMenu.moveToTrash.one", bundle: .module, locale: locale)
        }
        let template = String(localized: "noteList.contextMenu.moveToTrash.many", bundle: .module, locale: locale)
        return String(format: template, count)
    }

    /// "Dupliquer" (1) / "Dupliquer N notes" (N > 1).
    public static func duplicate(count: Int, locale: Locale = .autoupdatingCurrent) -> String {
        if count == 1 {
            return String(localized: "noteList.contextMenu.duplicate.one", bundle: .module, locale: locale)
        }
        let template = String(localized: "noteList.contextMenu.duplicate.many", bundle: .module, locale: locale)
        return String(format: template, count)
    }

    /// "Ajouter aux favoris" (1) / "Ajouter N notes aux favoris" (N > 1). Voir
    /// `NoteContextMenuContent.isAllFavorite` (critere d'acceptation
    /// `docs/11_organisation_notes.md` : bascule de favori depuis le menu contextuel).
    public static func addFavorite(count: Int, locale: Locale = .autoupdatingCurrent) -> String {
        if count == 1 {
            return String(localized: "noteList.contextMenu.favorite.add.one", bundle: .module, locale: locale)
        }
        let template = String(localized: "noteList.contextMenu.favorite.add.many", bundle: .module, locale: locale)
        return String(format: template, count)
    }

    /// "Retirer des favoris" (1) / "Retirer N notes des favoris" (N > 1).
    public static func removeFavorite(count: Int, locale: Locale = .autoupdatingCurrent) -> String {
        if count == 1 {
            return String(localized: "noteList.contextMenu.favorite.remove.one", bundle: .module, locale: locale)
        }
        let template = String(localized: "noteList.contextMenu.favorite.remove.many", bundle: .module, locale: locale)
        return String(format: template, count)
    }
}
