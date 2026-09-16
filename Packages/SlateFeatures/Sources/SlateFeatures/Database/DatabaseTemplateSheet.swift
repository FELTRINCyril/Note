import SlateModel
import SlateUI
import SwiftUI

/// Editeur de template de fiche (17.6, artboard D) : nom + une valeur par defaut par
/// champ (`DatabaseTemplatePropertyRow`). Enregistre via `DatabaseTemplateStore`
/// (`DatabaseViewModel.saveTemplate(_:)`).
struct DatabaseTemplateEditorSheet: View {
    @Bindable var viewModel: DatabaseViewModel
    let template: DatabaseTemplate?
    let onDismiss: () -> Void

    @State private var name: String = ""
    @State private var values: [UUID: CellValue] = [:]

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text(String(localized: "database.template.editorTitle", bundle: .module))
                .slateFont(SlateFont.h3)
                .foregroundStyle(SlateColor.textPrimary)

            DatabaseBorderedRow {
                TextField(String(localized: "database.template.namePlaceholder", bundle: .module), text: $name)
                    .textFieldStyle(.plain)
            }

            ForEach(viewModel.snapshot.fields.filter(\.type.storesCellValue)) { field in
                DatabaseTemplatePropertyRow(field.name) {
                    propertyEditor(for: field)
                }
            }

            Spacer(minLength: 0)

            HStack(spacing: Spacing.sm) {
                DatabaseSecondaryButton(String(localized: "action.cancel", bundle: .module), action: onDismiss)
                DatabasePrimaryButton(String(localized: "action.save", bundle: .module), action: commit)
            }
        }
        .padding(Spacing.lg)
        .frame(width: 320)
        .onAppear(perform: seed)
    }

    @ViewBuilder
    private func propertyEditor(for field: DatabaseFieldSnapshot) -> some View {
        switch field.type {
        case .text, .url:
            TextField("", text: textBinding(for: field))
                .textFieldStyle(.plain)
        case .number:
            TextField("", value: numberBinding(for: field), format: .number)
                .textFieldStyle(.plain)
        case .checkbox:
            DatabaseCheckboxToggle(isChecked: checkboxBinding(for: field))
        case .singleSelect:
            Menu {
                Button(String(localized: "database.template.noValue", bundle: .module)) { values[field.id] = nil }
                ForEach(field.configuration.selectOptions ?? []) { option in
                    Button(option.label) { values[field.id] = .singleSelect(option.id) }
                }
            } label: {
                Text(currentLabel(for: field))
                    .slateFont(SlateFont.caption)
                    .foregroundStyle(SlateColor.textPrimary)
            }
        default:
            Text(String(localized: "database.template.unsupportedField", bundle: .module))
                .slateFont(SlateFont.caption)
                .foregroundStyle(SlateColor.textTertiary)
        }
    }

    private func currentLabel(for field: DatabaseFieldSnapshot) -> String {
        guard case .singleSelect(let optionID)? = values[field.id],
              let option = field.configuration.selectOptions?.first(where: { $0.id == optionID })
        else {
            return String(localized: "database.template.noValue", bundle: .module)
        }
        return option.label
    }

    private func textBinding(for field: DatabaseFieldSnapshot) -> Binding<String> {
        Binding(
            get: {
                if case .text(let text)? = values[field.id] { return text }
                if case .url(let text)? = values[field.id] { return text }
                return ""
            },
            set: { values[field.id] = field.type == .url ? .url($0) : .text($0) }
        )
    }

    private func numberBinding(for field: DatabaseFieldSnapshot) -> Binding<Double> {
        Binding(
            get: { if case .number(let number)? = values[field.id] { return number }; return 0 },
            set: { values[field.id] = .number($0) }
        )
    }

    private func checkboxBinding(for field: DatabaseFieldSnapshot) -> Binding<Bool> {
        Binding(
            get: { if case .checkbox(let flag)? = values[field.id] { return flag }; return false },
            set: { values[field.id] = .checkbox($0) }
        )
    }

    private func seed() {
        guard let template else { return }
        name = template.name
        values = template.values
    }

    private func commit() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        let saved = DatabaseTemplate(id: template?.id ?? UUID(), name: trimmedName, values: values)
        viewModel.saveTemplate(saved)
        onDismiss()
    }
}

/// Menu "+ Nouvelle fiche" (`DatabaseAddRowButton` peut devenir un menu si plusieurs
/// templates existent, artboard D) : une entree par template + "Fiche vierge" +
/// "Gerer les templates...".
struct DatabaseTemplateMenu: View {
    @Bindable var viewModel: DatabaseViewModel
    let onManageTemplates: () -> Void

    var body: some View {
        if viewModel.templates.isEmpty {
            // Pas de nesting Button-dans-Menu tant qu'aucun template n'existe : un
            // simple ajout direct suffit (`DatabaseAddRowButton` reste un vrai bouton).
            DatabaseAddRowButton(title: String(localized: "database.grid.addRow", bundle: .module)) {
                viewModel.addRow()
            }
        } else {
            Menu {
                Button(String(localized: "database.template.blankRow", bundle: .module)) { viewModel.addRow() }
                Divider()
                ForEach(viewModel.templates) { template in
                    Button(template.name) { viewModel.applyTemplate(template) }
                }
                Divider()
                Button(String(localized: "database.template.manage", bundle: .module), action: onManageTemplates)
            } label: {
                // Meme habillage visuel que `DatabaseAddRowButton`, sans y imbriquer un
                // second `Button` (un `Button` comme LABEL d'un `Menu` intercepterait le
                // tap avant l'ouverture du menu).
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "plus").slateIconFont(12, weight: .semibold, relativeTo: .callout)
                    Text(String(localized: "database.grid.addRow", bundle: .module))
                }
                .slateFont(SlateFont.label)
                .foregroundStyle(SlateColor.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
            }
            .menuStyle(.borderlessButton)
        }
    }
}
