import Foundation

/// Operateur de filtre. Chaque cas ne s'applique qu'a un sous-ensemble de
/// `DatabaseFieldType` (documente au fil du type) ; applique a un type incompatible, il
/// est evalue comme "ne correspond pas" plutot que de lever une erreur - un filtre mal
/// configure ne doit jamais faire planter l'affichage d'une base, seulement ne rien
/// filtrer d'utile.
public enum DatabaseFilterOperator: Sendable, Equatable {
    /// Applicable a tous les types : aucune valeur saisie (ou valeur vide, voir
    /// `CellValue.isEmpty`).
    case isEmpty
    /// Applicable a tous les types : symetrique de `isEmpty`.
    case isNotEmpty

    // MARK: Texte / URL (`.text`, `.url`)
    case textEquals(String)
    case textNotEquals(String)
    case textContains(String)
    case textDoesNotContain(String)
    case textStartsWith(String)
    case textEndsWith(String)

    // MARK: Nombre (`.number`)
    case numberEquals(Double)
    case numberNotEquals(Double)
    case numberGreaterThan(Double)
    case numberLessThan(Double)
    case numberGreaterThanOrEqual(Double)
    case numberLessThanOrEqual(Double)

    // MARK: Date (`.date`, `.createdDate`, `.modifiedDate`)
    case dateIsOn(Date)
    case dateIsBefore(Date)
    case dateIsAfter(Date)
    case dateIsOnOrBefore(Date)
    case dateIsOnOrAfter(Date)

    // MARK: Case a cocher (`.checkbox`)
    case checkboxIs(Bool)

    // MARK: Selection unique (`.singleSelect`)
    case selectIs(UUID)
    case selectIsNot(UUID)
    case selectIsAnyOf([UUID])
    case selectIsNoneOf([UUID])

    // MARK: Selection multiple (`.multiSelect`)
    case multiSelectContainsAny([UUID])
    case multiSelectContainsAll([UUID])
    case multiSelectContainsNone([UUID])

    // MARK: Relation (`.relation`)
    case relationContains(UUID)
    case relationDoesNotContain(UUID)
}

/// Une condition de filtre : "le champ `fieldID` verifie `op`".
public struct DatabaseFilterCondition: Sendable, Equatable {
    public var fieldID: UUID
    public var op: DatabaseFilterOperator

    public init(fieldID: UUID, op: DatabaseFilterOperator) {
        self.fieldID = fieldID
        self.op = op
    }
}

/// Mode de combinaison des conditions d'un `DatabaseFilter`.
public enum DatabaseFilterCombinator: Sendable {
    case and
    case or
}

/// Filtre multi-criteres complet, applique par `DatabaseQueryEngine.filter`. Une liste
/// de conditions vide ne filtre rien (toutes les lignes correspondent).
public struct DatabaseFilter: Sendable {
    public var combinator: DatabaseFilterCombinator
    public var conditions: [DatabaseFilterCondition]

    public init(combinator: DatabaseFilterCombinator = .and, conditions: [DatabaseFilterCondition] = []) {
        self.combinator = combinator
        self.conditions = conditions
    }
}

extension DatabaseQueryEngine {
    /// Applique `filter` a `rows`. Les valeurs sont resolues via `evaluatedValue`
    /// (champs stockes ET calcules, `createdDate`/`modifiedDate`/`rollup` inclus).
    public static func filter(
        _ rows: [DatabaseRowSnapshot],
        with filter: DatabaseFilter,
        fields: [DatabaseFieldSnapshot],
        relatedDatabases: [UUID: DatabaseSnapshot] = [:]
    ) -> [DatabaseRowSnapshot] {
        guard !filter.conditions.isEmpty else { return rows }
        return rows.filter { row in
            let results = filter.conditions.map { condition -> Bool in
                let value = evaluatedValue(
                    for: condition.fieldID,
                    in: row,
                    fields: fields,
                    relatedDatabases: relatedDatabases
                )
                return evaluate(condition.op, against: value)
            }
            switch filter.combinator {
            case .and:
                return results.allSatisfy { $0 }
            case .or:
                return results.contains(true)
            }
        }
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    private static func evaluate(_ op: DatabaseFilterOperator, against value: CellValue?) -> Bool {
        switch op {
        case .isEmpty:
            return value == nil || value?.isEmpty == true
        case .isNotEmpty:
            return !(value == nil || value?.isEmpty == true)
        case .textEquals(let text):
            return textValue(value) == text
        case .textNotEquals(let text):
            return textValue(value) != text
        case .textContains(let text):
            return textValue(value)?.localizedStandardContains(text) ?? false
        case .textDoesNotContain(let text):
            return !(textValue(value)?.localizedStandardContains(text) ?? false)
        case .textStartsWith(let text):
            return textValue(value)?.hasPrefix(text) ?? false
        case .textEndsWith(let text):
            return textValue(value)?.hasSuffix(text) ?? false
        case .numberEquals(let number):
            return numberValue(value) == number
        case .numberNotEquals(let number):
            return numberValue(value) != number
        case .numberGreaterThan(let number):
            return (numberValue(value) ?? .nan) > number
        case .numberLessThan(let number):
            return (numberValue(value) ?? .nan) < number
        case .numberGreaterThanOrEqual(let number):
            return (numberValue(value) ?? .nan) >= number
        case .numberLessThanOrEqual(let number):
            return (numberValue(value) ?? .nan) <= number
        case .dateIsOn(let date):
            return dateValue(value).map { Calendar.current.isDate($0, inSameDayAs: date) } ?? false
        case .dateIsBefore(let date):
            return (dateValue(value) ?? .distantFuture) < date
        case .dateIsAfter(let date):
            return (dateValue(value) ?? .distantPast) > date
        case .dateIsOnOrBefore(let date):
            return (dateValue(value) ?? .distantFuture) <= date
        case .dateIsOnOrAfter(let date):
            return (dateValue(value) ?? .distantPast) >= date
        case .checkboxIs(let expected):
            let actual: Bool = if case .checkbox(let stored)? = value { stored } else { false }
            return actual == expected
        case .selectIs(let optionID):
            guard case .singleSelect(let actual)? = value else { return false }
            return actual == optionID
        case .selectIsNot(let optionID):
            guard case .singleSelect(let actual)? = value else { return true }
            return actual != optionID
        case .selectIsAnyOf(let optionIDs):
            guard case .singleSelect(let actual)? = value else { return false }
            return optionIDs.contains(actual)
        case .selectIsNoneOf(let optionIDs):
            guard case .singleSelect(let actual)? = value else { return true }
            return !optionIDs.contains(actual)
        case .multiSelectContainsAny(let optionIDs):
            guard case .multiSelect(let actual)? = value else { return false }
            return !Set(actual).isDisjoint(with: optionIDs)
        case .multiSelectContainsAll(let optionIDs):
            guard case .multiSelect(let actual)? = value else { return false }
            return Set(optionIDs).isSubset(of: Set(actual))
        case .multiSelectContainsNone(let optionIDs):
            guard case .multiSelect(let actual)? = value else { return true }
            return Set(actual).isDisjoint(with: optionIDs)
        case .relationContains(let rowID):
            guard case .relation(let actual)? = value else { return false }
            return actual.contains(rowID)
        case .relationDoesNotContain(let rowID):
            guard case .relation(let actual)? = value else { return true }
            return !actual.contains(rowID)
        }
    }

    private static func textValue(_ value: CellValue?) -> String? {
        switch value {
        case .text(let text), .url(let text):
            text
        default:
            nil
        }
    }

    private static func numberValue(_ value: CellValue?) -> Double? {
        guard case .number(let number)? = value else { return nil }
        return number
    }

    private static func dateValue(_ value: CellValue?) -> Date? {
        guard case .date(let date)? = value else { return nil }
        return date
    }
}
