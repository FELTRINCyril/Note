import SlateModel
import SlateUI
import SwiftData
import SwiftUI

/// Grille CRUD d'une base inline (voir `DatabaseViewBlockContentView`). CRUD complet
/// (ajout/suppression de ligne, edition de cellule) via `DatabaseQueryEngine`/
/// `Database+Integrity` -- jamais un `modelContext.delete(...)` direct sur une ligne, un
/// champ ou une base (voir la documentation de tete de `Database+Integrity.swift`,
/// `SlateModel`).
struct InlineDatabaseGridView: View {
    let database: Database
    let modelContext: ModelContext

    @State private var isAddingField = false

    private var snapshot: DatabaseSnapshot { database.makeSnapshot() }
    private var fields: [DatabaseFieldSnapshot] { snapshot.fields.sorted { $0.order < $1.order } }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            ForEach(snapshot.rows) { row in
                rowView(row)
            }
            DatabaseAddRowButton(title: EditorStrings.databaseViewAddRow, action: addRow)
        }
        .background(SlateColor.bgEditor)
        .overlay(
            RoundedRectangle(cornerRadius: SlateGeometry.radiusSmall).strokeBorder(SlateColor.databaseGridCellBorder)
        )
        .clipShape(RoundedRectangle(cornerRadius: SlateGeometry.radiusSmall))
        .popover(isPresented: $isAddingField) {
            InlineDatabaseFieldAdditionView(database: database, modelContext: modelContext, isPresented: $isAddingField)
        }
    }

    private var header: some View {
        HStack(spacing: 0) {
            ForEach(fields) { field in
                DatabaseColumnHeaderCell(
                    title: field.name,
                    systemImage: InlineDatabaseFieldGlyph.systemImage(for: field.type)
                )
                    .frame(width: 160)
            }
            Button {
                isAddingField = true
            } label: {
                Image(systemName: "plus")
                    .slateIconFont(12, weight: .semibold, relativeTo: .callout)
                    .foregroundStyle(SlateColor.textSecondary)
                    .padding(.horizontal, Spacing.md)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(EditorStrings.databaseViewAddField)
        }
    }

    private func rowView(_ row: DatabaseRowSnapshot) -> some View {
        HStack(spacing: 0) {
            ForEach(fields) { field in
                InlineDatabaseCellView(
                    field: field,
                    value: row.values[field.id],
                    onCommit: { setCellValue($0, rowID: row.id, fieldID: field.id) }
                )
                .frame(width: 160)
            }
        }
        .contextMenu {
            Button(role: .destructive) { deleteRow(row.id) } label: {
                Label(EditorStrings.databaseViewDeleteRow, systemImage: "trash")
            }
        }
    }

    private func addRow() {
        guard let row = database.rows else { return }
        let newRow = DatabaseRow(order: row.count, database: database)
        modelContext.insert(newRow)
        database.rows?.append(newRow)
        try? modelContext.save()
    }

    private func deleteRow(_ rowID: UUID) {
        guard let target = database.rows?.first(where: { $0.id == rowID }) else { return }
        Database.deleteRow(target, from: modelContext)
        try? modelContext.save()
    }

    private func setCellValue(_ value: CellValue?, rowID: UUID, fieldID: UUID) {
        guard let row = database.rows?.first(where: { $0.id == rowID }) else { return }
        guard let field = database.fields?.first(where: { $0.id == fieldID }) else { return }
        let cell = row.setCellValue(value, for: field)
        if cell.modelContext == nil { modelContext.insert(cell) }
        try? modelContext.save()
    }
}

/// Glyphe de type de champ (memes icones que le catalogue complet de `SlateFeatures`,
/// duplique volontairement ici : deux modules distincts, pas de dependance permise entre
/// eux, voir la documentation de tete de `DatabaseViewBlockContentView`).
enum InlineDatabaseFieldGlyph {
    static func systemImage(for type: DatabaseFieldType) -> String {
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
