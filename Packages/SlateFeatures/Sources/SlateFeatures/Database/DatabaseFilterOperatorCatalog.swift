import Foundation
import SlateModel

/// Une entree du menu "operateur" d'une condition de filtre : titre localise + valeur
/// `DatabaseFilterOperator` PAR DEFAUT associee (la valeur precise, si l'operateur en
/// porte une, est ensuite ajustee par le picker de valeur - voir
/// `DatabaseFilterSortGroupMenu.valueChip(for:index:)`).
struct DatabaseFilterOperatorDescriptor: Identifiable {
    let id: String
    let title: String
    let op: DatabaseFilterOperator

    static func selectIs(_ optionID: UUID, label: String) -> DatabaseFilterOperatorDescriptor {
        DatabaseFilterOperatorDescriptor(id: "selectIs-\(optionID)", title: label, op: .selectIs(optionID))
    }
}

/// Operateurs de filtre proposes pour un champ, selon son `DatabaseFieldType` (17.4,
/// exigence explicite : "les operateurs proposes doivent dependre du type de champ").
enum DatabaseFilterOperatorCatalog {
    static func operators(for field: DatabaseFieldSnapshot) -> [DatabaseFilterOperatorDescriptor] {
        let common = [
            DatabaseFilterOperatorDescriptor(id: "isEmpty", title: title(for: .isEmpty), op: .isEmpty),
            DatabaseFilterOperatorDescriptor(id: "isNotEmpty", title: title(for: .isNotEmpty), op: .isNotEmpty)
        ]
        switch field.type {
        case .text, .url:
            return common + [
                descriptor("textEquals", .textEquals("")),
                descriptor("textNotEquals", .textNotEquals("")),
                descriptor("textContains", .textContains("")),
                descriptor("textDoesNotContain", .textDoesNotContain("")),
                descriptor("textStartsWith", .textStartsWith("")),
                descriptor("textEndsWith", .textEndsWith(""))
            ]
        case .number:
            return common + [
                descriptor("numberEquals", .numberEquals(0)),
                descriptor("numberNotEquals", .numberNotEquals(0)),
                descriptor("numberGreaterThan", .numberGreaterThan(0)),
                descriptor("numberLessThan", .numberLessThan(0)),
                descriptor("numberGreaterThanOrEqual", .numberGreaterThanOrEqual(0)),
                descriptor("numberLessThanOrEqual", .numberLessThanOrEqual(0))
            ]
        case .date, .createdDate, .modifiedDate:
            return common + [
                descriptor("dateIsOn", .dateIsOn(.now)),
                descriptor("dateIsBefore", .dateIsBefore(.now)),
                descriptor("dateIsAfter", .dateIsAfter(.now)),
                descriptor("dateIsOnOrBefore", .dateIsOnOrBefore(.now)),
                descriptor("dateIsOnOrAfter", .dateIsOnOrAfter(.now))
            ]
        case .checkbox:
            return [
                descriptor("checkboxIsTrue", .checkboxIs(true)),
                descriptor("checkboxIsFalse", .checkboxIs(false))
            ]
        case .singleSelect:
            return common + (field.configuration.selectOptions ?? []).map { .selectIs($0.id, label: $0.label) }
        case .multiSelect:
            return common + [
                descriptor(
                    "multiSelectContainsAny",
                    .multiSelectContainsAny((field.configuration.selectOptions ?? []).map(\.id))
                )
            ]
        case .relation:
            return common
        case .rollup:
            return common
        }
    }

    private static func descriptor(_ id: String, _ op: DatabaseFilterOperator) -> DatabaseFilterOperatorDescriptor {
        DatabaseFilterOperatorDescriptor(id: id, title: title(for: op), op: op)
    }

    // swiftlint:disable:next cyclomatic_complexity
    static func title(for op: DatabaseFilterOperator) -> String {
        switch op {
        case .isEmpty: String(localized: "database.filterOperator.isEmpty", bundle: .module)
        case .isNotEmpty: String(localized: "database.filterOperator.isNotEmpty", bundle: .module)
        case .textEquals: String(localized: "database.filterOperator.textEquals", bundle: .module)
        case .textNotEquals: String(localized: "database.filterOperator.textNotEquals", bundle: .module)
        case .textContains: String(localized: "database.filterOperator.textContains", bundle: .module)
        case .textDoesNotContain: String(localized: "database.filterOperator.textDoesNotContain", bundle: .module)
        case .textStartsWith: String(localized: "database.filterOperator.textStartsWith", bundle: .module)
        case .textEndsWith: String(localized: "database.filterOperator.textEndsWith", bundle: .module)
        case .numberEquals: String(localized: "database.filterOperator.numberEquals", bundle: .module)
        case .numberNotEquals: String(localized: "database.filterOperator.numberNotEquals", bundle: .module)
        case .numberGreaterThan: String(localized: "database.filterOperator.numberGreaterThan", bundle: .module)
        case .numberLessThan: String(localized: "database.filterOperator.numberLessThan", bundle: .module)
        case .numberGreaterThanOrEqual:
            String(localized: "database.filterOperator.numberGreaterThanOrEqual", bundle: .module)
        case .numberLessThanOrEqual:
            String(localized: "database.filterOperator.numberLessThanOrEqual", bundle: .module)
        case .dateIsOn: String(localized: "database.filterOperator.dateIsOn", bundle: .module)
        case .dateIsBefore: String(localized: "database.filterOperator.dateIsBefore", bundle: .module)
        case .dateIsAfter: String(localized: "database.filterOperator.dateIsAfter", bundle: .module)
        case .dateIsOnOrBefore: String(localized: "database.filterOperator.dateIsOnOrBefore", bundle: .module)
        case .dateIsOnOrAfter: String(localized: "database.filterOperator.dateIsOnOrAfter", bundle: .module)
        case .checkboxIs(let value): checkboxTitle(isTrue: value)
        case .selectIs: String(localized: "database.filterOperator.selectIs", bundle: .module)
        case .selectIsNot: String(localized: "database.filterOperator.selectIsNot", bundle: .module)
        case .selectIsAnyOf: String(localized: "database.filterOperator.selectIsAnyOf", bundle: .module)
        case .selectIsNoneOf: String(localized: "database.filterOperator.selectIsNoneOf", bundle: .module)
        case .multiSelectContainsAny:
            String(localized: "database.filterOperator.multiSelectContainsAny", bundle: .module)
        case .multiSelectContainsAll:
            String(localized: "database.filterOperator.multiSelectContainsAll", bundle: .module)
        case .multiSelectContainsNone:
            String(localized: "database.filterOperator.multiSelectContainsNone", bundle: .module)
        case .relationContains: String(localized: "database.filterOperator.relationContains", bundle: .module)
        case .relationDoesNotContain:
            String(localized: "database.filterOperator.relationDoesNotContain", bundle: .module)
        }
    }

    private static func checkboxTitle(isTrue: Bool) -> String {
        guard isTrue else { return String(localized: "database.filterOperator.checkboxIsFalse", bundle: .module) }
        return String(localized: "database.filterOperator.checkboxIsTrue", bundle: .module)
    }
}
