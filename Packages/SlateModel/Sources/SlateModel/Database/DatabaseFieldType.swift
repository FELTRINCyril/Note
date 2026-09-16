import Foundation

/// Type d'un champ (colonne) de base de donnees, Phase 17. Determine l'editeur affiche,
/// les operateurs de filtre valides et la source de la valeur (cellule stockee ou
/// calculee).
///
/// Enum `String`-backed, meme motif et meme regle d'evolution que `BlockType` : ne
/// jamais renommer/supprimer un cas une fois des donnees ecrites, seulement en ajouter.
public enum DatabaseFieldType: String, CaseIterable, Codable, Sendable {
    /// Texte libre. Valeur stockee : `CellValue.text`.
    case text
    /// Nombre, avec format d'affichage optionnel (`DatabaseFieldConfiguration.numberFormat`).
    /// Valeur stockee : `CellValue.number`.
    case number
    /// Date (sans heure ou avec heure, a la charge de l'UI). Valeur stockee : `CellValue.date`.
    case date
    /// Case a cocher. Valeur stockee : `CellValue.checkbox`.
    case checkbox
    /// Lien externe. Valeur stockee : `CellValue.url`.
    case url
    /// Selection unique parmi les options de `DatabaseFieldConfiguration.selectOptions`.
    /// Valeur stockee : `CellValue.singleSelect`.
    case singleSelect
    /// Selection multiple parmi les memes options. Valeur stockee : `CellValue.multiSelect`.
    case multiSelect

    /// Champ calcule : date de creation de la ligne porteuse (`DatabaseRow.createdAt`).
    /// N'a jamais de `DatabaseCell` associee, voir `DatabaseQueryEngine.evaluatedValue`.
    case createdDate
    /// Champ calcule : date de derniere modification de la ligne (`DatabaseRow.modifiedAt`).
    /// Meme remarque que `createdDate`.
    case modifiedDate

    /// Lien vers des lignes d'une autre base (`DatabaseFieldConfiguration.relationTargetDatabaseID`).
    /// Valeur stockee : `CellValue.relation`.
    case relation
    /// Agregation d'une valeur a travers un champ `.relation` de la meme base
    /// (`DatabaseFieldConfiguration.rollupSourceFieldID`/`rollupTargetFieldID`/`rollupOperation`).
    /// Champ calcule, jamais de `DatabaseCell` associee.
    case rollup

    /// Types dont la valeur est portee par une `DatabaseCell` reelle (les autres sont
    /// entierement calcules a la demande par `DatabaseQueryEngine`).
    public var storesCellValue: Bool {
        switch self {
        case .text, .number, .date, .checkbox, .url, .singleSelect, .multiSelect, .relation:
            true
        case .createdDate, .modifiedDate, .rollup:
            false
        }
    }
}
