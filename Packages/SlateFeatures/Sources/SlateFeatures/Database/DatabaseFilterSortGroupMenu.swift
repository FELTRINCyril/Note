import SlateModel
import SlateUI
import SwiftUI

/// Menu Filtres / Tris / Groupement (17.4, `docs/17_base_de_donnees.md`), branche sur
/// `DatabaseQueryEngine` via `DatabaseViewModel`. Les operateurs proposes pour une
/// condition dependent du type du champ selectionne (`DatabaseFilterOperatorCatalog`) -
/// exigence explicite de la phase.
struct DatabaseFilterSortGroupMenu: View {
    @Bindable var viewModel: DatabaseViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                filtersSection
                Divider()
                sortSection
                Divider()
                groupSection
            }
            .padding(Spacing.md)
        }
        .frame(width: 340, height: 420)
        .background(SlateColor.surfacePrimary)
    }

    // MARK: - Filtres

    private var filtersSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            DatabaseMenuSectionLabel(String(localized: "database.filters.title", bundle: .module))
            ForEach(Array(viewModel.filter.conditions.enumerated()), id: \.offset) { index, condition in
                conditionRow(condition, index: index)
            }
            DatabaseAddFilterActionsRow(
                onAddFilter: addFilter,
                onAddGroup: addFilter
            )
        }
    }

    private func conditionRow(_ condition: DatabaseFilterCondition, index: Int) -> some View {
        DatabaseConditionRow {
            Menu {
                ForEach(viewModel.snapshot.fields) { field in
                    Button(field.name) { updateConditionField(index: index, fieldID: field.id) }
                }
            } label: {
                DatabaseFilterChip(fieldName(condition.fieldID))
            }
            Menu {
                ForEach(availableOperators(for: condition.fieldID)) { descriptor in
                    Button(descriptor.title) { updateConditionOperator(index: index, descriptor: descriptor) }
                }
            } label: {
                DatabaseFilterChip(operatorTitle(condition.op))
            }
            valueChip(for: condition, index: index)
        } onRemove: {
            viewModel.filter.conditions.remove(at: index)
        }
    }

    @ViewBuilder
    private func valueChip(for condition: DatabaseFilterCondition, index: Int) -> some View {
        if let field = viewModel.snapshot.field(withID: condition.fieldID), needsValue(condition.op) {
            switch field.type {
            case .singleSelect:
                Menu {
                    ForEach(field.configuration.selectOptions ?? []) { option in
                        Button(option.label) {
                            let descriptor = DatabaseFilterOperatorDescriptor.selectIs(option.id, label: option.label)
                            updateConditionOperator(index: index, descriptor: descriptor)
                        }
                    }
                } label: {
                    DatabaseFilterChip(selectValueLabel(condition.op, field: field), fillsRemainingWidth: true)
                }
            default:
                DatabaseFilterChip(textValue(condition.op), fillsRemainingWidth: true)
            }
        }
    }

    private func addFilter() {
        guard let firstField = viewModel.snapshot.fields.first else { return }
        viewModel.filter.conditions.append(DatabaseFilterCondition(fieldID: firstField.id, op: .isNotEmpty))
    }

    private func updateConditionField(index: Int, fieldID: UUID) {
        guard viewModel.filter.conditions.indices.contains(index) else { return }
        viewModel.filter.conditions[index] = DatabaseFilterCondition(fieldID: fieldID, op: .isNotEmpty)
    }

    private func updateConditionOperator(index: Int, descriptor: DatabaseFilterOperatorDescriptor) {
        guard viewModel.filter.conditions.indices.contains(index) else { return }
        viewModel.filter.conditions[index].op = descriptor.op
    }

    private func availableOperators(for fieldID: UUID) -> [DatabaseFilterOperatorDescriptor] {
        guard let field = viewModel.snapshot.field(withID: fieldID) else { return [] }
        return DatabaseFilterOperatorCatalog.operators(for: field)
    }

    private func fieldName(_ fieldID: UUID) -> String {
        let fallback = String(localized: "database.filters.unknownField", bundle: .module)
        return viewModel.snapshot.field(withID: fieldID)?.name ?? fallback
    }

    private func operatorTitle(_ op: DatabaseFilterOperator) -> String {
        DatabaseFilterOperatorCatalog.title(for: op)
    }

    private func needsValue(_ op: DatabaseFilterOperator) -> Bool {
        switch op {
        case .isEmpty, .isNotEmpty:
            false
        default:
            true
        }
    }

    private func selectValueLabel(_ op: DatabaseFilterOperator, field: DatabaseFieldSnapshot) -> String {
        guard case .selectIs(let optionID) = op,
              let option = field.configuration.selectOptions?.first(where: { $0.id == optionID }) else {
            return String(localized: "database.filters.chooseValue", bundle: .module)
        }
        return option.label
    }

    private func textValue(_ op: DatabaseFilterOperator) -> String {
        switch op {
        case .textEquals(let value), .textNotEquals(let value), .textContains(let value),
             .textDoesNotContain(let value), .textStartsWith(let value), .textEndsWith(let value):
            value
        case .numberEquals(let value), .numberNotEquals(let value), .numberGreaterThan(let value),
             .numberLessThan(let value), .numberGreaterThanOrEqual(let value), .numberLessThanOrEqual(let value):
            String(format: "%g", value)
        case .checkboxIs(let value):
            booleanLabel(value)
        default:
            String(localized: "database.filters.chooseValue", bundle: .module)
        }
    }

    private func booleanLabel(_ value: Bool) -> String {
        guard value else { return String(localized: "action.no", bundle: .module) }
        return String(localized: "action.yes", bundle: .module)
    }

    // MARK: - Tris

    private var sortSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            DatabaseMenuSectionLabel(String(localized: "database.sort.title", bundle: .module))
            ForEach(Array(viewModel.sortDescriptors.enumerated()), id: \.offset) { index, descriptor in
                sortRow(descriptor, index: index)
            }
            DatabaseAddFilterActionsRow(onAddFilter: addSort, onAddGroup: addSort)
        }
    }

    private func sortRow(_ descriptor: DatabaseSortDescriptor, index: Int) -> some View {
        DatabaseConditionRow {
            Menu {
                ForEach(viewModel.snapshot.fields) { field in
                    Button(field.name) { viewModel.sortDescriptors[index].fieldID = field.id }
                }
            } label: {
                DatabaseFilterChip(fieldName(descriptor.fieldID))
            }
            Menu {
                Button(String(localized: "database.sort.ascending", bundle: .module)) {
                    viewModel.sortDescriptors[index].direction = .ascending
                }
                Button(String(localized: "database.sort.descending", bundle: .module)) {
                    viewModel.sortDescriptors[index].direction = .descending
                }
            } label: {
                DatabaseFilterChip(
                    descriptor.direction == .ascending
                        ? String(localized: "database.sort.ascending", bundle: .module)
                        : String(localized: "database.sort.descending", bundle: .module),
                    fillsRemainingWidth: true
                )
            }
        } onRemove: {
            viewModel.sortDescriptors.remove(at: index)
        }
    }

    private func addSort() {
        guard let firstField = viewModel.snapshot.fields.first else { return }
        viewModel.sortDescriptors.append(DatabaseSortDescriptor(fieldID: firstField.id))
    }

    // MARK: - Groupement

    private var groupSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            DatabaseMenuSectionLabel(String(localized: "database.group.title", bundle: .module))
            Menu {
                Button(String(localized: "database.group.none", bundle: .module)) { viewModel.groupFieldID = nil }
                ForEach(groupableFields) { field in
                    Button(field.name) { viewModel.groupFieldID = field.id }
                }
            } label: {
                DatabaseFilterChip(groupFieldTitle, fillsRemainingWidth: true)
            }
        }
    }

    private var groupableFields: [DatabaseFieldSnapshot] {
        viewModel.snapshot.fields.filter { $0.type == .singleSelect || $0.type == .multiSelect || $0.type == .checkbox }
    }

    private var groupFieldTitle: String {
        guard let groupFieldID = viewModel.groupFieldID else {
            return String(localized: "database.group.none", bundle: .module)
        }
        return fieldName(groupFieldID)
    }
}
