import SlateModel
import SlateUI
import SwiftUI

/// Vue Grille (17.3, `docs/17_base_de_donnees.md`) : en-tetes redimensionnables et
/// reordonnables, cellules editables en place, barre de calculs, ligne d'ajout.
struct DatabaseGridView: View {
    @Bindable var viewModel: DatabaseViewModel
    let onEditField: (UUID) -> Void
    let onAddField: () -> Void

    private static let defaultColumnWidth: CGFloat = 180

    var body: some View {
        ScrollView([.horizontal, .vertical]) {
            VStack(alignment: .leading, spacing: 0) {
                header
                ForEach(Array(viewModel.visibleRows.enumerated()), id: \.element.id) { index, row in
                    rowView(row, isAlternateRow: index.isMultiple(of: 2) == false)
                }
                DatabaseAddRowButton(title: String(localized: "database.grid.addRow", bundle: .module)) {
                    viewModel.addRow()
                }
                .frame(width: totalWidth, alignment: .leading)
                calculationBar
            }
        }
        .background(SlateColor.bgEditor)
    }

    private var header: some View {
        HStack(spacing: 0) {
            ForEach(viewModel.orderedFields) { field in
                DatabaseColumnHeaderCell(
                    title: field.name,
                    systemImage: systemImage(for: field.type),
                    sortDirection: sortDirection(for: field.id),
                    showsMenuGlyph: true,
                    onTap: { onEditField(field.id) }
                )
                .frame(width: width(for: field.id))
                .databaseColumnDraggable(columnID: field.id.uuidString)
                .dropDestination(for: String.self) { items, _ in
                    guard let sourceIDString = items.first, let sourceID = UUID(uuidString: sourceIDString) else {
                        return false
                    }
                    viewModel.moveColumn(sourceID, before: field.id)
                    return true
                }
                DatabaseColumnResizeHandle(width: widthBinding(for: field.id))
            }
            Button(action: onAddField) {
                Image(systemName: "plus")
                    .slateIconFont(12, weight: .semibold, relativeTo: .callout)
                    .foregroundStyle(SlateColor.textSecondary)
                    .padding(.horizontal, Spacing.md)
                    .frame(height: SlateGeometry.strokeHairline * 40)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(localized: "database.grid.addField", bundle: .module))
        }
    }

    private func rowView(_ row: DatabaseRowSnapshot, isAlternateRow: Bool) -> some View {
        HStack(spacing: 0) {
            ForEach(viewModel.orderedFields) { field in
                DatabaseGridCellView(
                    field: field,
                    value: viewModel.evaluatedValue(fieldID: field.id, row: row),
                    showsTrailingBorder: true,
                    isAlternateRow: isAlternateRow,
                    onCommit: { newValue in viewModel.setCellValue(newValue, rowID: row.id, fieldID: field.id) }
                )
                .frame(width: width(for: field.id))
            }
        }
        .contextMenu {
            Button(role: .destructive) {
                viewModel.deleteRow(row.id)
            } label: {
                Label(String(localized: "database.grid.deleteRow", bundle: .module), systemImage: "trash")
            }
        }
    }

    private var calculationBar: some View {
        HStack(spacing: 0) {
            ForEach(viewModel.orderedFields) { field in
                DatabaseCalculationBarCell(
                    result: viewModel.calculationResult(for: field.id),
                    calculation: viewModel.columnCalculations[field.id] ?? .none,
                    onSelect: { viewModel.columnCalculations[field.id] = $0 }
                )
                .frame(width: width(for: field.id))
            }
        }
    }

    private func width(for fieldID: UUID) -> CGFloat {
        viewModel.columnWidths[fieldID] ?? Self.defaultColumnWidth
    }

    private func widthBinding(for fieldID: UUID) -> Binding<CGFloat> {
        Binding(
            get: { width(for: fieldID) },
            set: { viewModel.columnWidths[fieldID] = $0 }
        )
    }

    private var totalWidth: CGFloat {
        viewModel.orderedFields.reduce(0) { $0 + width(for: $1.id) + Spacing.sm }
    }

    private func sortDirection(for fieldID: UUID) -> SlateDatabaseSortDirection? {
        guard let descriptor = viewModel.sortDescriptors.first(where: { $0.fieldID == fieldID }) else { return nil }
        return descriptor.direction == .ascending ? .ascending : .descending
    }

    private func systemImage(for type: DatabaseFieldType) -> String {
        switch type {
        case .text: "text.alignleft"
        case .number: "number"
        case .date, .createdDate, .modifiedDate: "calendar"
        case .checkbox: "checkmark.square"
        case .url: "link"
        case .singleSelect: "tag"
        case .multiSelect: "tag.fill"
        case .relation: "arrow.triangle.branch"
        case .rollup: "function"
        }
    }
}
