import Foundation
import SlateModel
import SlateUI

/// Mise en forme d'une `CellValue`/`DatabaseCalculationResult` en chaines affichables,
/// selon le type et la configuration du champ porteur. Fonctions pures : aucune vue ne
/// duplique ce calcul, elles consomment toutes ces chaines deja formees (design/
/// tokens.md §18 : les cellules de `SlateUI` sont des composants de PRESENTATION purs).
enum DatabaseCellFormatting {
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    private static let percentFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.maximumFractionDigits = 0
        return formatter
    }()

    private static let currencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        return formatter
    }()

    /// Texte affiche pour une cellule d'un champ donne, ou `nil` si aucune valeur (la
    /// vue decide alors de l'etat "placeholder").
    static func displayText(_ value: CellValue?, field: DatabaseFieldSnapshot) -> String? {
        guard let value else { return nil }
        switch (field.type, value) {
        case (.text, .text(let text)), (.url, .url(let text)):
            return text.isEmpty ? nil : text
        case (.number, .number(let number)):
            return formattedNumber(number, format: field.configuration.numberFormat)
        case (.date, .date(let date)), (.createdDate, .date(let date)), (.modifiedDate, .date(let date)):
            return dateFormatter.string(from: date)
        case (.checkbox, .checkbox):
            return nil
        default:
            return nil
        }
    }

    static func formattedNumber(_ number: Double, format: DatabaseNumberFormat?) -> String {
        switch format ?? .plain {
        case .plain:
            return String(format: "%g", number)
        case .integer:
            return String(Int(number.rounded()))
        case .percent:
            return percentFormatter.string(from: NSNumber(value: number)) ?? String(format: "%.0f %%", number * 100)
        case .currency:
            return currencyFormatter.string(from: NSNumber(value: number)) ?? String(format: "%.2f", number)
        }
    }

    /// Etiquettes (titre + style) d'une valeur `.singleSelect`/`.multiSelect`, dans
    /// l'ordre de `DatabaseFieldConfiguration.selectOptions`.
    static func tags(
        for value: CellValue?,
        field: DatabaseFieldSnapshot
    ) -> [(title: String, style: SlateDatabasePillStyle)] {
        let options = field.configuration.selectOptions ?? []
        let selectedIDs: [UUID]
        switch value {
        case .singleSelect(let id):
            selectedIDs = [id]
        case .multiSelect(let ids):
            selectedIDs = ids
        default:
            selectedIDs = []
        }
        return selectedIDs.compactMap { id in
            guard let option = options.first(where: { $0.id == id }) else { return nil }
            return (option.label, pillStyle(for: option))
        }
    }

    static func pillStyle(for option: DatabaseSelectOption) -> SlateDatabasePillStyle {
        SlateDatabasePillStyle(accent: DatabaseColorToken.accent(for: option.colorToken), bullet: .none)
    }

    /// Texte deja forme d'un `DatabaseCalculationResult` (barre de calculs, 17.3).
    static func text(for result: DatabaseCalculationResult, calculation: SlateDatabaseColumnCalculation) -> String? {
        switch result {
        case .empty:
            return nil
        case .count(let count):
            return String(format: String(localized: "database.calculation.count", bundle: .module), count)
        case .number(let number):
            return String(format: "%g", number)
        case .percent(let percent):
            return percentFormatter.string(from: NSNumber(value: percent)) ?? String(format: "%.0f %%", percent * 100)
        }
    }
}
