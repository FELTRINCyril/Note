import SlateModel
import SlateUI
import SwiftUI

/// Une cellule de `InlineDatabaseGridView` : rendu par type + editeur en place au clic,
/// pour les champs qui `storesCellValue`. Version compacte de la cellule pleine page de
/// `SlateFeatures` (voir la documentation de tete de `DatabaseViewBlockContentView`).
struct InlineDatabaseCellView: View {
    let field: DatabaseFieldSnapshot
    let value: CellValue?
    let onCommit: (CellValue?) -> Void

    @State private var isEditorPresented = false

    var body: some View {
        Button {
            guard field.type.storesCellValue else { return }
            isEditorPresented = true
        } label: {
            DatabaseGridCell {
                content
            }
        }
        .buttonStyle(.plain)
        .disabled(!field.type.storesCellValue)
        .popover(isPresented: $isEditorPresented) {
            InlineDatabaseCellEditor(field: field, value: value, onCommit: onCommit)
        }
    }

    @ViewBuilder private var content: some View {
        switch field.type {
        case .text:
            if case .text(let text)? = value, !text.isEmpty {
                DatabaseTextCellView(text)
            } else {
                DatabaseTextCellView("", isPlaceholder: true)
            }
        case .url:
            if case .url(let text)? = value, !text.isEmpty {
                DatabaseURLCellView(text)
            } else {
                DatabaseTextCellView("", isPlaceholder: true)
            }
        case .number:
            if case .number(let number)? = value {
                DatabaseNumberCellView(String(format: "%g", number))
            } else {
                DatabaseNumberCellView("")
            }
        case .date, .createdDate, .modifiedDate:
            if case .date(let date)? = value {
                DatabaseDateCellView(Self.dateFormatter.string(from: date))
            } else {
                DatabaseDateCellView("", isPlaceholder: true)
            }
        case .checkbox:
            let isChecked: Bool = if case .checkbox(let flag)? = value { flag } else { false }
            DatabaseCheckboxToggle(isChecked: .constant(isChecked)).allowsHitTesting(false)
        case .singleSelect, .multiSelect, .relation, .rollup:
            DatabaseTextCellView(EditorStrings.databaseViewUnsupportedCellType, isPlaceholder: true)
        }
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter
    }()
}

/// Editeur en place minimal (texte/nombre/date/case a cocher). Les selections
/// (`.singleSelect`/`.multiSelect`) restent en lecture seule dans une base inline :
/// configurer leurs options exige l'editeur de champ complet, reserve a l'hebergement
/// pleine page (voir `DatabaseGridView` de `SlateFeatures`) - limite assumee, pas une
/// fausse promesse (aucun bouton d'edition n'est propose pour ces deux types ici).
struct InlineDatabaseCellEditor: View {
    let field: DatabaseFieldSnapshot
    let value: CellValue?
    let onCommit: (CellValue?) -> Void

    @State private var text = ""
    @State private var number: Double = 0
    @State private var date = Date.now
    @State private var isChecked = false

    var body: some View {
        Group {
            switch field.type {
            case .text:
                TextField(EditorStrings.databaseViewCellValue, text: $text)
                    .onChange(of: text) { _, newValue in onCommit(newValue.isEmpty ? nil : .text(newValue)) }
            case .url:
                TextField(EditorStrings.databaseViewCellValue, text: $text)
                    .onChange(of: text) { _, newValue in onCommit(newValue.isEmpty ? nil : .url(newValue)) }
            case .number:
                TextField(EditorStrings.databaseViewCellValue, value: $number, format: .number)
                    .onChange(of: number) { _, newValue in onCommit(.number(newValue)) }
            case .date:
                DatePicker(EditorStrings.databaseViewCellValue, selection: $date, displayedComponents: .date)
                    .labelsHidden()
                    .onChange(of: date) { _, newValue in onCommit(.date(newValue)) }
            case .checkbox:
                DatabaseCheckboxToggle(isChecked: $isChecked)
                    .onChange(of: isChecked) { _, newValue in onCommit(.checkbox(newValue)) }
            case .createdDate, .modifiedDate, .singleSelect, .multiSelect, .relation, .rollup:
                EmptyView()
            }
        }
        .textFieldStyle(.plain)
        .padding(Spacing.sm)
        .frame(minWidth: 160)
        .onAppear {
            switch value {
            case .text(let stored), .url(let stored): text = stored
            case .number(let stored): number = stored
            case .date(let stored): date = stored
            case .checkbox(let stored): isChecked = stored
            default: break
            }
        }
    }
}
