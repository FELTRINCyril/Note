import SlateModel
import SlateUI
import SwiftUI

/// Editeur de champ (17.2/17.3, artboard D) : creer, renommer, changer de type,
/// configurer les options d'une selection, supprimer. `fieldID == nil` cree un nouveau
/// champ ; sinon edite le champ existant.
struct DatabaseFieldEditorSheet: View {
    @Bindable var viewModel: DatabaseViewModel
    let fieldID: UUID?
    let onDismiss: () -> Void

    @State private var name: String = ""
    @State private var type: DatabaseFieldType = .text
    @State private var options: [DatabaseSelectOption] = []

    /// Configuration `.relation` : base ciblee, choisie parmi `viewModel.relatedDatabases`.
    @State private var relationTargetDatabaseID: UUID?

    /// Configuration `.rollup` : champ `.relation` de LA MEME base a suivre, champ a
    /// agreger dans la base ciblee par cette relation, et operation d'agregation --
    /// voir `DatabaseFieldConfiguration`.
    @State private var rollupSourceFieldID: UUID?
    @State private var rollupTargetFieldID: UUID?
    @State private var rollupOperation: DatabaseRollupOperation = .count

    private var isEditingExistingField: Bool { fieldID != nil }

    /// Types proposables a la creation/edition d'un champ : les champs calcules
    /// `createdDate`/`modifiedDate` ne sont jamais choisis manuellement, ils existent
    /// uniquement pour documenter un type deja en place (voir
    /// `DatabaseFieldType.storesCellValue`). `relation`/`rollup` restent proposables
    /// UNIQUEMENT parce que cette feuille sait desormais les configurer entierement
    /// (base cible / relation source + champ + operation) -- la regle d'honnetete
    /// d'interface du projet (jamais un champ propose sans pouvoir etre rendu
    /// utilisable) interdisait de les lister sans cette configuration.
    private static let assignableFieldTypes = DatabaseFieldType.allCases.filter {
        $0 != .createdDate && $0 != .modifiedDate
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text(
                isEditingExistingField
                    ? String(localized: "database.fieldEditor.editTitle", bundle: .module)
                    : String(localized: "database.fieldEditor.addTitle", bundle: .module)
            )
            .slateFont(SlateFont.h3)
            .foregroundStyle(SlateColor.textPrimary)

            DatabaseBorderedRow {
                TextField(String(localized: "database.fieldEditor.namePlaceholder", bundle: .module), text: $name)
                    .textFieldStyle(.plain)
            }

            VStack(alignment: .leading, spacing: Spacing.xs) {
                ForEach(Self.assignableFieldTypes, id: \.self) { candidate in
                    DatabaseFieldTypeRow(
                        title: DatabaseFieldTypeLabels.title(for: candidate),
                        detail: DatabaseFieldTypeLabels.detail(for: candidate),
                        isSelected: type == candidate,
                        action: { type = candidate }
                    )
                }
            }

            if type == .singleSelect || type == .multiSelect {
                optionsEditor
            }
            if type == .relation {
                relationEditor
            }
            if type == .rollup {
                rollupEditor
            }

            Spacer(minLength: 0)

            HStack(spacing: Spacing.sm) {
                if isEditingExistingField {
                    Button(role: .destructive) {
                        if let fieldID { viewModel.deleteField(fieldID) }
                        onDismiss()
                    } label: {
                        Text(String(localized: "database.fieldEditor.delete", bundle: .module))
                    }
                    Spacer(minLength: 0)
                }
                DatabaseSecondaryButton(String(localized: "action.cancel", bundle: .module), action: onDismiss)
                DatabasePrimaryButton(String(localized: "action.save", bundle: .module), action: commit)
            }
        }
        .padding(Spacing.lg)
        .frame(width: 340)
        .onAppear(perform: seed)
    }

    private var optionsEditor: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            DatabaseMenuSectionLabel(String(localized: "database.fieldEditor.options", bundle: .module))
            ForEach(options) { option in
                DatabaseFieldOptionRow(
                    title: option.label,
                    style: DatabaseCellFormatting.pillStyle(for: option),
                    onRemove: { options.removeAll { $0.id == option.id } }
                )
            }
            DatabaseAddOptionRow {
                let label = String(localized: "database.fieldEditor.newOption", bundle: .module)
                options.append(DatabaseSelectOption(label: label, colorToken: DatabaseColorToken.neutralToken))
            }
        }
    }

    // MARK: - Relation

    private var relationEditor: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            DatabaseMenuSectionLabel(String(localized: "database.fieldEditor.relationTarget", bundle: .module))
            if viewModel.relatedDatabases.isEmpty {
                Text(String(localized: "database.fieldEditor.relation.noTarget", bundle: .module))
                    .slateFont(SlateFont.caption)
                    .foregroundStyle(SlateColor.textSecondary)
            } else {
                Menu {
                    ForEach(viewModel.relatedDatabases, id: \.id) { database in
                        Button(displayName(for: database)) { relationTargetDatabaseID = database.id }
                    }
                } label: {
                    DatabaseFilterChip(relationTargetLabel, fillsRemainingWidth: true)
                }
            }
        }
    }

    private var relationTargetLabel: String {
        guard let relationTargetDatabaseID,
              let database = viewModel.relatedDatabases.first(where: { $0.id == relationTargetDatabaseID }) else {
            return String(localized: "database.fieldEditor.chooseDatabase", bundle: .module)
        }
        return displayName(for: database)
    }

    private func displayName(for database: Database) -> String {
        database.name.isEmpty ? String(localized: "database.untitled", bundle: .module) : database.name
    }

    // MARK: - Rollup

    private var rollupEditor: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            DatabaseMenuSectionLabel(String(localized: "database.fieldEditor.rollup", bundle: .module))
            if relationFieldsOfCurrentDatabase.isEmpty {
                Text(String(localized: "database.fieldEditor.rollup.noRelationField", bundle: .module))
                    .slateFont(SlateFont.caption)
                    .foregroundStyle(SlateColor.textSecondary)
            } else {
                Menu {
                    ForEach(relationFieldsOfCurrentDatabase) { relationField in
                        Button(relationField.name) {
                            rollupSourceFieldID = relationField.id
                            rollupTargetFieldID = nil
                        }
                    }
                } label: {
                    DatabaseFilterChip(rollupSourceLabel, fillsRemainingWidth: true)
                }
                if let targetFields = rollupTargetCandidateFields, !targetFields.isEmpty {
                    Menu {
                        ForEach(targetFields) { field in
                            Button(field.name) { rollupTargetFieldID = field.id }
                        }
                    } label: {
                        DatabaseFilterChip(rollupTargetLabel(among: targetFields), fillsRemainingWidth: true)
                    }
                    Menu {
                        ForEach(DatabaseRollupOperation.allCases, id: \.self) { operation in
                            Button(DatabaseFieldTypeLabels.rollupOperationTitle(operation)) {
                                rollupOperation = operation
                            }
                        }
                    } label: {
                        DatabaseFilterChip(
                            DatabaseFieldTypeLabels.rollupOperationTitle(rollupOperation),
                            fillsRemainingWidth: true
                        )
                    }
                }
            }
        }
    }

    /// Champs `.relation` de LA MEME base : seuls candidats valables pour
    /// `rollupSourceFieldID` (`DatabaseFieldConfiguration.rollupSourceFieldID` doit
    /// pointer un champ `.relation` de la base porteuse du rollup, voir
    /// `DatabaseQueryEngine.evaluatedRollup`).
    private var relationFieldsOfCurrentDatabase: [DatabaseFieldSnapshot] {
        viewModel.snapshot.fields.filter { $0.type == .relation }
    }

    private var rollupSourceLabel: String {
        guard let rollupSourceFieldID,
              let field = relationFieldsOfCurrentDatabase.first(where: { $0.id == rollupSourceFieldID }) else {
            return String(localized: "database.fieldEditor.chooseRelationField", bundle: .module)
        }
        return field.name
    }

    /// Champs de la base CIBLEE par `rollupSourceFieldID`, candidats pour
    /// `rollupTargetFieldID`. `nil` tant qu'aucune relation source n'est choisie.
    private var rollupTargetCandidateFields: [DatabaseFieldSnapshot]? {
        guard let rollupSourceFieldID,
              let sourceField = relationFieldsOfCurrentDatabase.first(where: { $0.id == rollupSourceFieldID }),
              let targetDatabaseID = sourceField.configuration.relationTargetDatabaseID,
              let targetDatabase = viewModel.relatedDatabases.first(where: { $0.id == targetDatabaseID })
        else {
            return nil
        }
        return targetDatabase.makeSnapshot().fields
    }

    private func rollupTargetLabel(among fields: [DatabaseFieldSnapshot]) -> String {
        guard let rollupTargetFieldID, let field = fields.first(where: { $0.id == rollupTargetFieldID }) else {
            return String(localized: "database.fieldEditor.chooseField", bundle: .module)
        }
        return field.name
    }

    private func seed() {
        guard let fieldID, let field = viewModel.snapshot.field(withID: fieldID) else { return }
        name = field.name
        type = field.type
        options = field.configuration.selectOptions ?? []
        relationTargetDatabaseID = field.configuration.relationTargetDatabaseID
        rollupSourceFieldID = field.configuration.rollupSourceFieldID
        rollupTargetFieldID = field.configuration.rollupTargetFieldID
        rollupOperation = field.configuration.rollupOperation ?? .count
    }

    /// Configuration a ecrire pour le type courant (`type`), ou `nil` si ce type n'a
    /// besoin d'aucune configuration (texte, nombre, date...). Point d'entree UNIQUE
    /// pour les 3 types configurables (selection/relation/rollup) : evite de dupliquer
    /// la meme logique entre creation et edition (voir `commit()`).
    private var configurationForCurrentType: DatabaseFieldConfiguration? {
        switch type {
        case .singleSelect, .multiSelect:
            DatabaseFieldConfiguration(selectOptions: options)
        case .relation:
            DatabaseFieldConfiguration(relationTargetDatabaseID: relationTargetDatabaseID)
        case .rollup:
            DatabaseFieldConfiguration(
                rollupSourceFieldID: rollupSourceFieldID,
                rollupTargetFieldID: rollupTargetFieldID,
                rollupOperation: rollupOperation
            )
        case .text, .number, .date, .checkbox, .url, .createdDate, .modifiedDate:
            nil
        }
    }

    private func commit() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        let fieldToConfigure: UUID
        if let fieldID {
            viewModel.renameField(fieldID, to: trimmedName)
            if viewModel.snapshot.field(withID: fieldID)?.type != type {
                viewModel.changeFieldType(fieldID, to: type)
            }
            fieldToConfigure = fieldID
        } else {
            fieldToConfigure = viewModel.addField(name: trimmedName, type: type).id
        }

        if let configuration = configurationForCurrentType {
            viewModel.updateFieldConfiguration(fieldToConfigure, configuration)
        }
        onDismiss()
    }
}

/// Libelles localises des types de champ (titre + detail secondaire, artboard D). Vit
/// ici plutot que dans `EditorStrings`/`SlateUIStrings` : c'est une chaine PROPRE a
/// l'editeur de champ de `SlateFeatures`, ni un libelle de bloc d'editeur ni un libelle
/// de composant `SlateUI` generique.
enum DatabaseFieldTypeLabels {
    static func title(for type: DatabaseFieldType) -> String {
        switch type {
        case .text: String(localized: "database.fieldType.text", bundle: .module)
        case .number: String(localized: "database.fieldType.number", bundle: .module)
        case .date: String(localized: "database.fieldType.date", bundle: .module)
        case .checkbox: String(localized: "database.fieldType.checkbox", bundle: .module)
        case .url: String(localized: "database.fieldType.url", bundle: .module)
        case .singleSelect: String(localized: "database.fieldType.singleSelect", bundle: .module)
        case .multiSelect: String(localized: "database.fieldType.multiSelect", bundle: .module)
        case .createdDate: String(localized: "database.fieldType.createdDate", bundle: .module)
        case .modifiedDate: String(localized: "database.fieldType.modifiedDate", bundle: .module)
        case .relation: String(localized: "database.fieldType.relation", bundle: .module)
        case .rollup: String(localized: "database.fieldType.rollup", bundle: .module)
        }
    }

    static func detail(for type: DatabaseFieldType) -> String? {
        switch type {
        case .number: String(localized: "database.fieldType.number.detail", bundle: .module)
        default: nil
        }
    }

    /// Libelle localise d'une operation de rollup (memes operations que la barre de
    /// calculs de colonne, voir `DatabaseQueryEngine.aggregate`).
    static func rollupOperationTitle(_ operation: DatabaseRollupOperation) -> String {
        switch operation {
        case .count: String(localized: "database.rollupOperation.count", bundle: .module)
        case .countFilled: String(localized: "database.rollupOperation.countFilled", bundle: .module)
        case .countEmpty: String(localized: "database.rollupOperation.countEmpty", bundle: .module)
        case .sum: String(localized: "database.rollupOperation.sum", bundle: .module)
        case .average: String(localized: "database.rollupOperation.average", bundle: .module)
        case .min: String(localized: "database.rollupOperation.min", bundle: .module)
        case .max: String(localized: "database.rollupOperation.max", bundle: .module)
        case .percentFilled: String(localized: "database.rollupOperation.percentFilled", bundle: .module)
        case .percentEmpty: String(localized: "database.rollupOperation.percentEmpty", bundle: .module)
        }
    }
}
