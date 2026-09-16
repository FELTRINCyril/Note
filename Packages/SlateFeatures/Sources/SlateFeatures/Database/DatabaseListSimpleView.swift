import SlateModel
import SlateUI
import SwiftUI

/// Vue Liste (17.5) : une `DatabaseListRowView` compacte par ligne, regroupees par
/// `DatabaseViewModel.groupFieldID` quand un groupement est actif (memes groupes que le
/// Kanban, `DatabaseQueryEngine.group`) - sinon une liste plate.
struct DatabaseListSimpleView: View {
    @Bindable var viewModel: DatabaseViewModel
    @State private var hoveredRowID: UUID?

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                if let groupFieldID = viewModel.groupFieldID {
                    ForEach(viewModel.groups, id: \.key) { group in
                        ListSectionHeader(groupTitle(group.key, fieldID: groupFieldID), count: group.rows.count)
                        ForEach(group.rows) { row in rowView(row) }
                    }
                } else {
                    ForEach(viewModel.visibleRows) { row in rowView(row) }
                }
            }
        }
        .background(SlateColor.bgList)
    }

    private func rowView(_ row: DatabaseRowSnapshot) -> some View {
        DatabaseListRowView(
            title: title(row),
            pill: pill(row),
            trailingText: trailingText(row),
            isHovered: hoveredRowID == row.id
        )
        .onHover { isHovering in hoveredRowID = isHovering ? row.id : nil }
        .contextMenu {
            Button(role: .destructive) { viewModel.deleteRow(row.id) } label: {
                Label(String(localized: "database.grid.deleteRow", bundle: .module), systemImage: "trash")
            }
        }
    }

    private func groupTitle(_ key: DatabaseGroupKey, fieldID: UUID) -> String {
        let options = viewModel.snapshot.field(withID: fieldID)?.configuration.selectOptions
        guard case .option(let optionID) = key, let option = options?.first(where: { $0.id == optionID }) else {
            return String(localized: "database.kanban.noValue", bundle: .module)
        }
        return option.label
    }

    private func title(_ row: DatabaseRowSnapshot) -> String {
        guard let field = viewModel.snapshot.fields.first(where: { $0.type == .text }) else {
            return String(localized: "database.kanban.untitledCard", bundle: .module)
        }
        return DatabaseCellFormatting.displayText(row.values[field.id], field: field)
            ?? String(localized: "database.kanban.untitledCard", bundle: .module)
    }

    private func pill(_ row: DatabaseRowSnapshot) -> (title: String, style: SlateDatabasePillStyle)? {
        guard let field = viewModel.snapshot.fields.first(where: { $0.type == .singleSelect }) else { return nil }
        return DatabaseCellFormatting.tags(for: row.values[field.id], field: field).first
    }

    private func trailingText(_ row: DatabaseRowSnapshot) -> String? {
        guard let field = viewModel.snapshot.fields.first(where: { $0.type == .date }) else { return nil }
        return DatabaseCellFormatting.displayText(row.values[field.id], field: field)
    }
}
