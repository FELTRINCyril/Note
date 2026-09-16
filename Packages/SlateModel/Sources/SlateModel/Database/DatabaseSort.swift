import Foundation

/// Un niveau de tri : trier par `fieldID`, dans `direction`. `DatabaseQueryEngine.sort`
/// accepte un tableau de `DatabaseSortDescriptor` pour un tri multi-niveaux (le premier
/// element depute, les suivants ne servent qu'a departager une egalite du precedent).
///
/// Reutilise `SortDirection` (deja public, defini pour la liste de notes en Phase 4,
/// `NoteSorting.swift`) plutot que de redefinir un enum equivalent : meme notion,
/// aucune raison d'en avoir deux dans `SlateModel`.
public struct DatabaseSortDescriptor: Sendable {
    public var fieldID: UUID
    public var direction: SortDirection

    public init(fieldID: UUID, direction: SortDirection = .ascending) {
        self.fieldID = fieldID
        self.direction = direction
    }
}

extension DatabaseQueryEngine {
    /// Trie `rows` selon `descriptors`, du premier (prioritaire) au dernier
    /// (departage). Une ligne dont la valeur du champ est absente/vide est toujours
    /// classee en dernier pour ce niveau de tri, quelle que soit `direction` - le
    /// comportement standard d'un tableur (une cellule vide n'est ni "petite" ni
    /// "grande", elle n'a pas de position naturelle dans l'ordre). Le dernier recours en
    /// cas d'egalite totale est `id`, pour un ordre determiste et stable.
    public static func sort(
        _ rows: [DatabaseRowSnapshot],
        by descriptors: [DatabaseSortDescriptor],
        fields: [DatabaseFieldSnapshot],
        relatedDatabases: [UUID: DatabaseSnapshot] = [:]
    ) -> [DatabaseRowSnapshot] {
        guard !descriptors.isEmpty else { return rows }
        return rows.sorted { lhs, rhs in
            for descriptor in descriptors {
                let comparison = compare(
                    lhs,
                    rhs,
                    descriptor: descriptor,
                    fields: fields,
                    relatedDatabases: relatedDatabases
                )
                if comparison != .orderedSame {
                    return comparison == .orderedAscending
                }
            }
            return lhs.id.uuidString < rhs.id.uuidString
        }
    }

    private static func compare(
        _ lhs: DatabaseRowSnapshot,
        _ rhs: DatabaseRowSnapshot,
        descriptor: DatabaseSortDescriptor,
        fields: [DatabaseFieldSnapshot],
        relatedDatabases: [UUID: DatabaseSnapshot]
    ) -> ComparisonResult {
        let lhsValue = evaluatedValue(
            for: descriptor.fieldID, in: lhs, fields: fields, relatedDatabases: relatedDatabases
        )
        let rhsValue = evaluatedValue(
            for: descriptor.fieldID, in: rhs, fields: fields, relatedDatabases: relatedDatabases
        )

        let lhsFilled = lhsValue.map { !$0.isEmpty } ?? false
        let rhsFilled = rhsValue.map { !$0.isEmpty } ?? false
        guard lhsFilled, rhsFilled else {
            if lhsFilled == rhsFilled { return .orderedSame }
            // Une valeur absente/vide est toujours classee en dernier, direction ignoree.
            return lhsFilled ? .orderedAscending : .orderedDescending
        }

        let field = fields.first { $0.id == descriptor.fieldID }
        let natural = compareFilledValues(lhsValue, rhsValue, selectOptions: field?.configuration.selectOptions)
        return descriptor.direction == .ascending ? natural : natural.reversed
    }

    private static func compareFilledValues(
        _ lhs: CellValue?,
        _ rhs: CellValue?,
        selectOptions: [DatabaseSelectOption]?
    ) -> ComparisonResult {
        switch (lhs, rhs) {
        case (.text(let left), .text(let right)), (.url(let left), .url(let right)):
            return left.localizedStandardCompare(right)
        case (.number(let left), .number(let right)):
            return compareComparable(left, right)
        case (.date(let left), .date(let right)):
            return compareComparable(left, right)
        case (.checkbox(let left), .checkbox(let right)):
            return compareComparable(left ? 1 : 0, right ? 1 : 0)
        case (.singleSelect(let left), .singleSelect(let right)):
            let leftIndex = selectOptions?.firstIndex { $0.id == left } ?? Int.max
            let rightIndex = selectOptions?.firstIndex { $0.id == right } ?? Int.max
            return compareComparable(leftIndex, rightIndex)
        case (.multiSelect(let left), .multiSelect(let right)):
            return compareComparable(left.count, right.count)
        case (.relation(let left), .relation(let right)):
            return compareComparable(left.count, right.count)
        default:
            return .orderedSame
        }
    }

    private static func compareComparable<Value: Comparable>(_ lhs: Value, _ rhs: Value) -> ComparisonResult {
        if lhs == rhs { return .orderedSame }
        return lhs < rhs ? .orderedAscending : .orderedDescending
    }
}

extension ComparisonResult {
    fileprivate var reversed: ComparisonResult {
        switch self {
        case .orderedAscending: .orderedDescending
        case .orderedDescending: .orderedAscending
        case .orderedSame: .orderedSame
        }
    }
}
