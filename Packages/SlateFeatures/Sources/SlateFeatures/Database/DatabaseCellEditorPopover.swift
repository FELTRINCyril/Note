import SlateModel
import SlateUI
import SwiftUI

/// Editeur en place d'une cellule de grille (17.3 : "edition inline par type de
/// cellule"), un par `DatabaseFieldType` qui `storesCellValue`. Les champs calcules
/// (`createdDate`/`modifiedDate`/`rollup`) ne sont jamais editables : voir
/// `DatabaseFieldType.storesCellValue`, verifie par l'appelant (`DatabaseGridCellView`)
/// avant meme de proposer le popover.
struct DatabaseCellEditorPopover: View {
    let field: DatabaseFieldSnapshot
    let value: CellValue?
    let onCommit: (CellValue?) -> Void

    @State private var text: String = ""
    @State private var number: Double = 0
    @State private var date = Date.now
    @State private var isChecked = false
    @State private var selectedOptionID: UUID?
    @State private var selectedOptionIDs: Set<UUID> = []

    var body: some View {
        Group {
            switch field.type {
            case .text, .url:
                TextField(String(localized: "database.cellEditor.value", bundle: .module), text: $text)
                    .textFieldStyle(.plain)
                    .onSubmit { commitText() }
                    .onChange(of: text) { _, _ in commitText() }
            case .number:
                TextField(
                    String(localized: "database.cellEditor.value", bundle: .module),
                    value: $number,
                    format: .number
                )
                    .textFieldStyle(.plain)
                    .onChange(of: number) { _, newValue in onCommit(.number(newValue)) }
            case .date:
                DatePicker(
                    String(localized: "database.cellEditor.value", bundle: .module),
                    selection: $date,
                    displayedComponents: .date
                )
                .labelsHidden()
                .onChange(of: date) { _, newValue in onCommit(.date(newValue)) }
            case .checkbox:
                DatabaseCheckboxToggle(isChecked: $isChecked)
                    .onChange(of: isChecked) { _, newValue in onCommit(.checkbox(newValue)) }
            case .singleSelect:
                singleSelectOptions
            case .multiSelect:
                multiSelectOptions
            case .createdDate, .modifiedDate, .rollup, .relation:
                EmptyView()
            }
        }
        .padding(Spacing.sm)
        .frame(minWidth: 180)
        .onAppear(perform: seed)
    }

    @ViewBuilder private var singleSelectOptions: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            ForEach(field.configuration.selectOptions ?? []) { option in
                Button {
                    selectedOptionID = selectedOptionID == option.id ? nil : option.id
                    onCommit(selectedOptionID.map { .singleSelect($0) })
                } label: {
                    DatabaseFieldTypeRow(title: option.label, isSelected: selectedOptionID == option.id)
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder private var multiSelectOptions: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            ForEach(field.configuration.selectOptions ?? []) { option in
                Button {
                    if selectedOptionIDs.contains(option.id) {
                        selectedOptionIDs.remove(option.id)
                    } else {
                        selectedOptionIDs.insert(option.id)
                    }
                    onCommit(.multiSelect(Array(selectedOptionIDs)))
                } label: {
                    DatabaseFieldTypeRow(title: option.label, isSelected: selectedOptionIDs.contains(option.id))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func commitText() {
        switch field.type {
        case .text:
            onCommit(text.isEmpty ? nil : .text(text))
        case .url:
            onCommit(text.isEmpty ? nil : .url(text))
        default:
            break
        }
    }

    private func seed() {
        switch value {
        case .text(let stored), .url(let stored):
            text = stored
        case .number(let stored):
            number = stored
        case .date(let stored):
            date = stored
        case .checkbox(let stored):
            isChecked = stored
        case .singleSelect(let stored):
            selectedOptionID = stored
        case .multiSelect(let stored):
            selectedOptionIDs = Set(stored)
        default:
            break
        }
    }
}
