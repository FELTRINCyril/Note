import Foundation

/// Moteur de requete des bases de donnees (Phase 17.4, `docs/17_base_de_donnees.md`) :
/// filtres, tris, regroupement et calculs. Namespace de fonctions pures (aucun etat,
/// aucune dependance SwiftData) operant sur des `DatabaseSnapshot`/`DatabaseRowSnapshot`/
/// `DatabaseFieldSnapshot` - testable directement depuis `SlateModelTests`, sans
/// `ModelContext`, comme l'exige explicitement le document de phase.
///
/// Les fonctions qui evaluent un champ `.rollup` ou `.relation` ont besoin d'acceder a
/// la base ciblee par la relation : elle est passee explicitement via `relatedDatabases`
/// (base cible indexee par son `id`), jamais parcourue implicitement - ce module n'a pas
/// connaissance d'un `ModelContext` pour aller la chercher lui-meme.
public enum DatabaseQueryEngine {
    /// Valeur "effective" d'un champ pour une ligne : lit `row.values` pour un champ
    /// stocke, ou calcule la valeur pour un champ derive (`createdDate`, `modifiedDate`,
    /// `rollup`). Retourne `nil` si le champ est introuvable, si aucune valeur n'a ete
    /// saisie, ou si un `rollup` reference un champ/une relation qui n'existe plus
    /// (comportement volontairement silencieux et sans crash, voir
    /// `docs/17_base_de_donnees.md` : "un rollup dont le champ source disparait doit se
    /// comporter proprement").
    public static func evaluatedValue(
        for fieldID: UUID,
        in row: DatabaseRowSnapshot,
        fields: [DatabaseFieldSnapshot],
        relatedDatabases: [UUID: DatabaseSnapshot] = [:]
    ) -> CellValue? {
        guard let field = fields.first(where: { $0.id == fieldID }) else { return nil }
        switch field.type {
        case .createdDate:
            return .date(row.createdAt)
        case .modifiedDate:
            return .date(row.modifiedAt)
        case .rollup:
            return evaluatedRollup(field: field, row: row, fields: fields, relatedDatabases: relatedDatabases)
        case .text, .number, .date, .checkbox, .url, .singleSelect, .multiSelect, .relation:
            return row.values[fieldID]
        }
    }

    /// Resultat d'agregation d'un champ `.rollup` pour une ligne : suit son
    /// `rollupSourceFieldID` (un champ `.relation` de la meme base) pour trouver les
    /// lignes ciblees dans la base distante, lit `rollupTargetFieldID` sur chacune, puis
    /// applique `rollupOperation` via `aggregate` (le meme calcul que la barre de
    /// calculs de colonne).
    private static func evaluatedRollup(
        field: DatabaseFieldSnapshot,
        row: DatabaseRowSnapshot,
        fields: [DatabaseFieldSnapshot],
        relatedDatabases: [UUID: DatabaseSnapshot]
    ) -> CellValue? {
        let configuration = field.configuration
        guard
            let sourceFieldID = configuration.rollupSourceFieldID,
            let sourceField = fields.first(where: { $0.id == sourceFieldID }),
            sourceField.type == .relation,
            let targetDatabaseID = sourceField.configuration.relationTargetDatabaseID,
            let targetDatabase = relatedDatabases[targetDatabaseID],
            let targetFieldID = configuration.rollupTargetFieldID,
            let operation = configuration.rollupOperation,
            case .relation(let targetRowIDs)? = row.values[sourceFieldID]
        else {
            return nil
        }

        let targetRows = targetDatabase.rows.filter { targetRowIDs.contains($0.id) }
        let targetValues = targetRows.map { targetRow in
            evaluatedValue(
                for: targetFieldID,
                in: targetRow,
                fields: targetDatabase.fields,
                relatedDatabases: relatedDatabases
            )
        }
        return resultToCellValue(aggregate(rollupToColumnCalculation(operation), values: targetValues))
    }

    private static func rollupToColumnCalculation(_ operation: DatabaseRollupOperation) -> DatabaseColumnCalculation {
        switch operation {
        case .count: .count
        case .countFilled: .countFilled
        case .countEmpty: .countEmpty
        case .sum: .sum
        case .average: .average
        case .min: .min
        case .max: .max
        case .percentFilled: .percentFilled
        case .percentEmpty: .percentEmpty
        }
    }

    private static func resultToCellValue(_ result: DatabaseCalculationResult) -> CellValue? {
        switch result {
        case .count(let value):
            .number(Double(value))
        case .number(let value), .percent(let value):
            .number(value)
        case .empty:
            nil
        }
    }
}
