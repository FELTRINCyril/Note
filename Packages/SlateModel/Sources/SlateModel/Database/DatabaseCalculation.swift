import Foundation

/// Calcul de colonne (barre de calculs de la vue Grille, 17.3) ou operation d'un champ
/// `.rollup` (17.2) : les deux partagent exactement le meme jeu d'operations, voir
/// `DatabaseQueryEngine.aggregate`.
public enum DatabaseColumnCalculation: Sendable, CaseIterable {
    case none
    case count
    case countFilled
    case countEmpty
    case sum
    case average
    case min
    case max
    case percentFilled
    case percentEmpty
}

/// Resultat d'un calcul de colonne ou d'un rollup. Type de resultat distinct de
/// `CellValue` : un calcul peut produire un compte ou un pourcentage, deux notions
/// absentes de la valeur d'une cellule elle-meme.
public enum DatabaseCalculationResult: Sendable, Equatable {
    case count(Int)
    case number(Double)
    case percent(Double)
    /// Aucune valeur calculable (colonne vide, `.none`, ou operation non applicable au
    /// type de champ - ex. `.sum` sur un champ texte).
    case empty
}

extension DatabaseQueryEngine {
    /// Calcule `calculation` pour la colonne `fieldID` sur `rows` (barre de calculs de
    /// la vue Grille, 17.3) : resout la valeur effective de chaque ligne via
    /// `evaluatedValue` (champs stockes ET calcules), puis delegue a `aggregate`.
    public static func calculate(
        _ calculation: DatabaseColumnCalculation,
        fieldID: UUID,
        in rows: [DatabaseRowSnapshot],
        fields: [DatabaseFieldSnapshot],
        relatedDatabases: [UUID: DatabaseSnapshot] = [:]
    ) -> DatabaseCalculationResult {
        let values = rows.map {
            evaluatedValue(for: fieldID, in: $0, fields: fields, relatedDatabases: relatedDatabases)
        }
        return aggregate(calculation, values: values)
    }

    /// Calcule `calculation` sur les valeurs deja resolues de `values` (une valeur par
    /// ligne, `nil` si absente/vide pour cette ligne). Fonction pure partagee par la
    /// barre de calculs de colonne et par l'evaluation d'un champ `.rollup`
    /// (`evaluatedValue`) : un rollup n'est jamais qu'un calcul applique aux valeurs des
    /// lignes ciblees par une relation plutot qu'aux lignes de la base courante.
    public static func aggregate(
        _ calculation: DatabaseColumnCalculation,
        values: [CellValue?]
    ) -> DatabaseCalculationResult {
        switch calculation {
        case .none:
            return .empty
        case .count:
            return .count(values.count)
        case .countFilled:
            return .count(values.filter { isFilled($0) }.count)
        case .countEmpty:
            return .count(values.filter { !isFilled($0) }.count)
        case .percentFilled:
            return percent(values) { isFilled($0) }
        case .percentEmpty:
            return percent(values) { !isFilled($0) }
        case .sum, .average, .min, .max:
            return numericAggregate(calculation, values: values)
        }
    }

    private static func isFilled(_ value: CellValue?) -> Bool {
        guard let value else { return false }
        return !value.isEmpty
    }

    private static func percent(
        _ values: [CellValue?],
        matching predicate: (CellValue?) -> Bool
    ) -> DatabaseCalculationResult {
        guard !values.isEmpty else { return .empty }
        let matching = values.filter(predicate).count
        return .percent(Double(matching) / Double(values.count))
    }

    private static func numericAggregate(
        _ calculation: DatabaseColumnCalculation,
        values: [CellValue?]
    ) -> DatabaseCalculationResult {
        let numbers: [Double] = values.compactMap { value in
            guard case .number(let number)? = value else { return nil }
            return number
        }
        guard !numbers.isEmpty else { return .empty }
        switch calculation {
        case .sum:
            return .number(numbers.reduce(0, +))
        case .average:
            return .number(numbers.reduce(0, +) / Double(numbers.count))
        case .min:
            return .number(numbers.min() ?? 0)
        case .max:
            return .number(numbers.max() ?? 0)
        case .none, .count, .countFilled, .countEmpty, .percentFilled, .percentEmpty:
            return .empty
        }
    }
}
