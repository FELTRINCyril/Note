import Foundation
import SwiftData
import Testing
import SlateModel
import SlateUI
@testable import SlateFeatures

/// Chemins critiques de la Phase 17 (17.3/17.5/17.6, `docs/17_base_de_donnees.md`) :
/// CRUD d'une ligne, edition d'une cellule de chaque type, bascule entre vues sur les
/// memes donnees, deplacement Kanban qui met a jour le champ de regroupement,
/// suppression d'un champ/d'une ligne SANS orphelin, application d'un template. Vrai
/// `ModelContainer` en memoire, `fetch` apres `save()` -- meme motif que
/// `EditorControllerDeletionPurgeTests` (`SlateEditor`).
@MainActor
@Suite("DatabaseViewModel")
struct DatabaseViewModelTests {
    private struct Fixture {
        let viewModel: DatabaseViewModel
        let database: Database
        let textField: DatabaseField
        let statusField: DatabaseField
        let context: ModelContext
    }

    /// Base avec un champ Texte ("Nom") et un champ Selection unique ("Statut", options
    /// "A faire"/"En cours").
    private func makeFixture() throws -> Fixture {
        let container = try SlateContainer.make(inMemory: true)
        let context = ModelContext(container)
        let database = Database(name: "Suivi", hostMode: .fullPage)
        context.insert(database)

        let textField = DatabaseField(name: "Nom", order: 0, fieldType: .text, database: database)
        let todoOption = DatabaseSelectOption(label: "A faire", colorToken: "neutral")
        let inProgressOption = DatabaseSelectOption(label: "En cours", colorToken: "blue")
        let statusField = DatabaseField(
            name: "Statut",
            order: 1,
            fieldType: .singleSelect,
            database: database,
            configuration: DatabaseFieldConfiguration(selectOptions: [todoOption, inProgressOption])
        )
        context.insert(textField)
        context.insert(statusField)
        database.fields = [textField, statusField]
        try context.save()

        let viewModel = DatabaseViewModel(database: database, modelContext: context)
        return Fixture(
            viewModel: viewModel, database: database, textField: textField, statusField: statusField, context: context
        )
    }

    // MARK: - CRUD de ligne

    @Test("addRow cree une ligne reellement persistee, deleteRow la retire sans orphelin")
    func addAndDeleteRowPersistReally() throws {
        let fixture = try makeFixture()
        let row = fixture.viewModel.addRow()

        let fetchedRows = try fixture.context.fetch(FetchDescriptor<DatabaseRow>())
        #expect(fetchedRows.contains { $0.id == row.id })
        #expect(fixture.viewModel.visibleRows.count == 1)

        fixture.viewModel.deleteRow(row.id)

        let remainingRows = try fixture.context.fetch(FetchDescriptor<DatabaseRow>())
        #expect(remainingRows.isEmpty)
        #expect(fixture.viewModel.visibleRows.isEmpty)
    }

    // MARK: - Edition de cellule par type

    @Test("setCellValue ecrit et relit correctement une valeur texte")
    func setCellValueText() throws {
        let fixture = try makeFixture()
        let row = fixture.viewModel.addRow()

        fixture.viewModel.setCellValue(.text("Editeur de blocs"), rowID: row.id, fieldID: fixture.textField.id)

        let value = fixture.viewModel.evaluatedValue(fieldID: fixture.textField.id, row: fixture.viewModel.visibleRows[0])
        #expect(value == .text("Editeur de blocs"))
    }

    @Test("setCellValue ecrit et relit correctement une valeur de selection unique")
    func setCellValueSingleSelect() throws {
        let fixture = try makeFixture()
        let row = fixture.viewModel.addRow()
        let optionID = try #require(fixture.statusField.configuration?.selectOptions?.first?.id)

        fixture.viewModel.setCellValue(.singleSelect(optionID), rowID: row.id, fieldID: fixture.statusField.id)

        let value = fixture.viewModel.evaluatedValue(fieldID: fixture.statusField.id, row: fixture.viewModel.visibleRows[0])
        #expect(value == .singleSelect(optionID))
    }

    @Test("setCellValue ecrit et relit correctement nombre, date et case a cocher")
    func setCellValueNumberDateCheckbox() throws {
        let fixture = try makeFixture()
        let numberField = fixture.viewModel.addField(name: "Avancement", type: .number)
        let dateField = fixture.viewModel.addField(name: "Echeance", type: .date)
        let checkboxField = fixture.viewModel.addField(name: "Fait", type: .checkbox)
        let row = fixture.viewModel.addRow()
        let date = Date(timeIntervalSince1970: 1_000_000)

        fixture.viewModel.setCellValue(.number(42), rowID: row.id, fieldID: numberField.id)
        fixture.viewModel.setCellValue(.date(date), rowID: row.id, fieldID: dateField.id)
        fixture.viewModel.setCellValue(.checkbox(true), rowID: row.id, fieldID: checkboxField.id)

        let refreshedRow = fixture.viewModel.visibleRows[0]
        #expect(fixture.viewModel.evaluatedValue(fieldID: numberField.id, row: refreshedRow) == .number(42))
        #expect(fixture.viewModel.evaluatedValue(fieldID: dateField.id, row: refreshedRow) == .date(date))
        #expect(fixture.viewModel.evaluatedValue(fieldID: checkboxField.id, row: refreshedRow) == .checkbox(true))
    }

    // MARK: - Bascule entre vues sur les memes donnees

    @Test("Changer viewKind ne change ni les lignes ni les filtres/tris : memes donnees dans les 5 vues")
    func switchingViewKindKeepsSameData() throws {
        let fixture = try makeFixture()
        fixture.viewModel.setCellValue(.text("Ligne A"), rowID: fixture.viewModel.addRow().id, fieldID: fixture.textField.id)
        fixture.viewModel.setCellValue(.text("Ligne B"), rowID: fixture.viewModel.addRow().id, fieldID: fixture.textField.id)
        fixture.viewModel.sortDescriptors = [DatabaseSortDescriptor(fieldID: fixture.textField.id, direction: .ascending)]

        let rowsInGrid = fixture.viewModel.visibleRows.map(\.id)

        for kind in SlateDatabaseViewKind.allCases {
            fixture.viewModel.viewKind = kind
            #expect(fixture.viewModel.visibleRows.map(\.id) == rowsInGrid)
        }
    }

    // MARK: - Kanban : deplacement met a jour le champ de regroupement

    @Test("moveRow(toGroup:fieldID:) met a jour la valeur du champ singleSelect de la ligne deplacee")
    func moveRowUpdatesGroupingField() throws {
        let fixture = try makeFixture()
        let row = fixture.viewModel.addRow()
        let todoID = try #require(fixture.statusField.configuration?.selectOptions?.first?.id)
        let inProgressID = try #require(fixture.statusField.configuration?.selectOptions?.last?.id)
        fixture.viewModel.setCellValue(.singleSelect(todoID), rowID: row.id, fieldID: fixture.statusField.id)

        fixture.viewModel.moveRow(row.id, toGroup: inProgressID, fieldID: fixture.statusField.id)

        let value = fixture.viewModel.evaluatedValue(fieldID: fixture.statusField.id, row: fixture.viewModel.visibleRows[0])
        #expect(value == .singleSelect(inProgressID))
    }

    // MARK: - Suppression sans orphelin

    @Test("deleteField supprime le champ et toutes ses cellules, sans laisser de reference morte")
    func deleteFieldPurgesCellsWithoutOrphan() throws {
        let fixture = try makeFixture()
        let row = fixture.viewModel.addRow()
        fixture.viewModel.setCellValue(.text("A supprimer"), rowID: row.id, fieldID: fixture.textField.id)

        fixture.viewModel.deleteField(fixture.textField.id)

        let fetchedFields = try fixture.context.fetch(FetchDescriptor<DatabaseField>())
        #expect(!fetchedFields.contains { $0.id == fixture.textField.id })
        let fetchedCells = try fixture.context.fetch(FetchDescriptor<DatabaseCell>())
        #expect(!fetchedCells.contains { $0.field?.id == fixture.textField.id })
    }

    @Test("Supprimer une base pleine page desamorce les relations qui la ciblaient dans une autre base")
    func deletingDatabaseDisarmsRelationsInOtherDatabases() throws {
        let fixture = try makeFixture()
        let otherDatabase = Database(name: "Autre", hostMode: .fullPage)
        fixture.context.insert(otherDatabase)
        let relationField = DatabaseField(
            name: "Lien",
            order: 0,
            fieldType: .relation,
            database: otherDatabase,
            configuration: DatabaseFieldConfiguration(relationTargetDatabaseID: fixture.database.id)
        )
        fixture.context.insert(relationField)
        otherDatabase.fields = [relationField]
        try fixture.context.save()

        Database.delete(fixture.database, from: fixture.context, relatedDatabases: [otherDatabase])
        try fixture.context.save()

        #expect(relationField.configuration?.relationTargetDatabaseID == nil)
    }

    // MARK: - Templates (17.6)

    @Test("applyTemplate cree une ligne pre-remplie avec les valeurs du template")
    func applyTemplateCreatesPrefilledRow() throws {
        let fixture = try makeFixture()
        let optionID = try #require(fixture.statusField.configuration?.selectOptions?.first?.id)
        let template = DatabaseTemplate(
            name: "Tache standard",
            values: [
                fixture.textField.id: .text("Nouvelle tache"),
                fixture.statusField.id: .singleSelect(optionID)
            ]
        )

        let row = fixture.viewModel.applyTemplate(template)

        let snapshotRow = fixture.viewModel.visibleRows.first { $0.id == row.id }
        let textValue = snapshotRow.flatMap { fixture.viewModel.evaluatedValue(fieldID: fixture.textField.id, row: $0) }
        let statusValue = snapshotRow.flatMap { fixture.viewModel.evaluatedValue(fieldID: fixture.statusField.id, row: $0) }
        #expect(textValue == .text("Nouvelle tache"))
        #expect(statusValue == .singleSelect(optionID))
    }
}
