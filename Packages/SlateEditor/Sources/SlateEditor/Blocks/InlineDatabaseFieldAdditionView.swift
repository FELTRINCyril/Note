import SlateModel
import SlateUI
import SwiftData
import SwiftUI

/// Ajout d'un champ depuis une base inline : nom + type parmi les types SANS
/// configuration additionnelle (texte/nombre/date/case a cocher/URL) - voir la
/// documentation de tete de `InlineDatabaseCellView` pour la raison de cette limite.
struct InlineDatabaseFieldAdditionView: View {
    let database: Database
    let modelContext: ModelContext
    @Binding var isPresented: Bool

    @State private var name = ""
    @State private var type: DatabaseFieldType = .text

    private static let assignableTypes: [DatabaseFieldType] = [.text, .number, .date, .checkbox, .url]

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            TextField(EditorStrings.databaseViewFieldNamePlaceholder, text: $name)
                .textFieldStyle(.plain)
            Picker(EditorStrings.databaseViewFieldNamePlaceholder, selection: $type) {
                ForEach(Self.assignableTypes, id: \.self) { candidate in
                    Text(EditorStrings.databaseFieldTypeLabel(candidate)).tag(candidate)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            DatabasePrimaryButton(EditorStrings.databaseViewAddField, action: addField)
        }
        .padding(Spacing.md)
        .frame(width: 220)
    }

    private func addField() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        let order = database.fields?.count ?? 0
        let field = DatabaseField(name: trimmedName, order: order, fieldType: type, database: database)
        modelContext.insert(field)
        database.fields?.append(field)
        try? modelContext.save()
        isPresented = false
    }
}
