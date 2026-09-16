import SlateModel
import SlateUI
import SwiftUI

/// Une cellule de la vue Grille : rendu par type (`DatabaseTextCellView`/
/// `DatabaseNumberCellView`/...) + editeur en place au clic (`DatabaseCellEditorPopover`)
/// pour les champs qui `storesCellValue` (17.3). Les champs calcules restent en LECTURE
/// SEULE : aucun popover ne s'ouvre, cliquer dessus n'a aucun effet - ils n'ont jamais de
/// `DatabaseCell` a ecrire (voir `DatabaseFieldType.storesCellValue`).
struct DatabaseGridCellView: View {
    let field: DatabaseFieldSnapshot
    let value: CellValue?
    let showsTrailingBorder: Bool
    let isAlternateRow: Bool
    let onCommit: (CellValue?) -> Void

    @State private var isEditorPresented = false

    var body: some View {
        Button {
            guard field.type.storesCellValue else { return }
            isEditorPresented = true
        } label: {
            DatabaseGridCell(showsTrailingBorder: showsTrailingBorder, isAlternateRow: isAlternateRow) {
                content
            }
        }
        .buttonStyle(.plain)
        .disabled(!field.type.storesCellValue)
        .popover(isPresented: $isEditorPresented) {
            DatabaseCellEditorPopover(field: field, value: value, onCommit: onCommit)
        }
        .accessibilityLabel(accessibilityLabel)
    }

    @ViewBuilder private var content: some View {
        switch field.type {
        case .text:
            DatabaseTextCellView(
                DatabaseCellFormatting.displayText(value, field: field) ?? "",
                isPlaceholder: DatabaseCellFormatting.displayText(value, field: field) == nil
            )
        case .url:
            if let text = DatabaseCellFormatting.displayText(value, field: field) {
                DatabaseURLCellView(text)
            } else {
                DatabaseTextCellView("", isPlaceholder: true)
            }
        case .number:
            DatabaseNumberCellView(DatabaseCellFormatting.displayText(value, field: field) ?? "")
        case .date, .createdDate, .modifiedDate:
            DatabaseDateCellView(
                DatabaseCellFormatting.displayText(value, field: field) ?? "",
                isPlaceholder: DatabaseCellFormatting.displayText(value, field: field) == nil
            )
        case .checkbox:
            if case .checkbox(let isChecked)? = value {
                DatabaseCheckboxToggle(isChecked: .constant(isChecked))
                    .allowsHitTesting(false)
            } else {
                DatabaseCheckboxToggle(isChecked: .constant(false)).allowsHitTesting(false)
            }
        case .singleSelect, .multiSelect:
            DatabaseTagsCellView(tags: DatabaseCellFormatting.tags(for: value, field: field))
        case .relation:
            if case .relation(let ids)? = value {
                let template = String(localized: "database.cell.relationCount", bundle: .module)
                DatabaseTextCellView(String(format: template, ids.count))
            } else {
                DatabaseTextCellView("", isPlaceholder: true)
            }
        case .rollup:
            DatabaseTextCellView(rollupDisplayText ?? "", isPlaceholder: rollupDisplayText == nil)
        }
    }

    private var rollupDisplayText: String? {
        guard case .number(let number)? = value else { return nil }
        return String(format: "%g", number)
    }

    private var accessibilityLabel: String {
        let emptyPlaceholder = String(localized: "database.cell.empty", bundle: .module)
        let text = DatabaseCellFormatting.displayText(value, field: field) ?? emptyPlaceholder
        return "\(field.name): \(text)"
    }
}
