import Foundation

/// Critere de tri disponible pour la liste de notes (colonne du milieu, Phase 4). Voir
/// `docs/04_liste_notes.md` et la spec E3 de `design/04_liste_notes/` : le menu de tri
/// propose exactement ces trois criteres, avec une bascule croissant/decroissant
/// (`SortDirection`) independante du critere.
public enum NoteSortCriterion: Sendable {
    /// Date de derniere modification (`Note.modifiedAt`). Critere par defaut.
    case modifiedDate
    /// Date de creation (`Note.createdAt`).
    case createdDate
    /// Titre, comparaison naturelle (`localizedStandardCompare`, insensible a la casse
    /// et aux accents), coherente avec le Finder et avec `SidebarOrdering`.
    case title
}

/// Direction d'un tri, independante du critere (`NoteSortCriterion`).
public enum SortDirection: Sendable {
    case ascending
    case descending
}

/// Filtre sur `Note.isPinned` applique par `NoteListQuery.notes(in:pinned:...)`. Voir
/// la documentation de cette methode : la spec E3 exige que les notes epinglees
/// n'apparaissent que dans la section "Epinglees" en haut de liste, jamais dupliquees
/// dans les groupes de date - `excludingPinned` est donc le filtre que la colonne de
/// liste doit utiliser pour ses groupes de date, `pinnedOnly` pour sa section
/// "Epinglees".
public enum NotePinnedFilter: Sendable {
    case all
    case pinnedOnly
    case excludingPinned
}

/// Ordre total et deterministe entre deux notes, pour un critere et une direction
/// donnes. Extrait en fonction libre (plutot que directement dans `NoteListQuery`) pour
/// rester testable isolement et reutilisable si un jour un second appelant a besoin du
/// meme tri (ex. export, recherche globale).
///
/// Le dernier recours (deux notes strictement egales sur le critere demande) est
/// toujours l'`id`, dans le meme ordre quelle que soit `direction` - exactement le
/// parti pris de `SidebarOrdering` : une direction inverse le sens du critere
/// "visible", pas la garantie de determinisme du cas d'egalite.
enum NoteSorting {
    static func isOrderedBefore(
        _ lhs: Note,
        _ rhs: Note,
        criterion: NoteSortCriterion,
        direction: SortDirection
    ) -> Bool {
        let ascending: Bool
        switch criterion {
        case .modifiedDate:
            if lhs.modifiedAt != rhs.modifiedAt {
                ascending = lhs.modifiedAt < rhs.modifiedAt
            } else {
                return tiebreak(lhs, rhs)
            }
        case .createdDate:
            if lhs.createdAt != rhs.createdAt {
                ascending = lhs.createdAt < rhs.createdAt
            } else {
                return tiebreak(lhs, rhs)
            }
        case .title:
            let comparison = lhs.title.localizedStandardCompare(rhs.title)
            if comparison != .orderedSame {
                ascending = comparison == .orderedAscending
            } else {
                return tiebreak(lhs, rhs)
            }
        }
        return direction == .ascending ? ascending : !ascending
    }

    private static func tiebreak(_ lhs: Note, _ rhs: Note) -> Bool {
        lhs.id.uuidString < rhs.id.uuidString
    }
}
