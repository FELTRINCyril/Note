import Foundation
import SwiftData
import Testing

@testable import SlateModel

/// Phase 17.1/17.2 : round-trip SwiftData reel (vrai `ModelContainer`, `fetch` apres
/// `save()`, voir piege n°5 de la consigne) de chaque type de valeur de cellule, des deux
/// modes d'hebergement, et des cascades de suppression exigees par
/// `docs/17_base_de_donnees.md` (aucun orphelin).
@MainActor
struct DatabaseModelPersistenceTests {
    private func makeContainer() throws -> ModelContainer {
        try SlateContainer.make(inMemory: true)
    }

    /// Construit et persiste une base pleine page avec un champ de chaque type porteur
    /// de cellule (voir `DatabaseFieldType.storesCellValue`), une seule ligne renseignee
    /// pour tous. Extrait de son test pour rester sous le seuil de longueur de fonction.
    private struct FullPageFixture {
        let optionA: DatabaseSelectOption
        let optionB: DatabaseSelectOption
    }

    @discardableResult
    private func makeFullPageFixture(in context: ModelContext) -> FullPageFixture {
        let folder = Folder(name: "Projets")
        let database = Database(name: "Taches", hostMode: .fullPage, folder: folder)

        let textField = DatabaseField(name: "Titre", order: 0, fieldType: .text, database: database)
        let numberField = DatabaseField(name: "Score", order: 1, fieldType: .number, database: database)
        let dateField = DatabaseField(name: "Echeance", order: 2, fieldType: .date, database: database)
        let checkboxField = DatabaseField(name: "Fait", order: 3, fieldType: .checkbox, database: database)
        let urlField = DatabaseField(name: "Lien", order: 4, fieldType: .url, database: database)
        let optionA = DatabaseSelectOption(label: "Haute", colorToken: "red")
        let optionB = DatabaseSelectOption(label: "Basse", colorToken: "blue")
        let singleSelectField = DatabaseField(
            name: "Priorite",
            order: 5,
            fieldType: .singleSelect,
            database: database,
            configuration: DatabaseFieldConfiguration(selectOptions: [optionA, optionB])
        )
        let multiSelectField = DatabaseField(
            name: "Etiquettes",
            order: 6,
            fieldType: .multiSelect,
            database: database,
            configuration: DatabaseFieldConfiguration(selectOptions: [optionA, optionB])
        )

        database.fields = [
            textField, numberField, dateField, checkboxField, urlField, singleSelectField, multiSelectField
        ]

        let row = DatabaseRow(database: database)
        database.rows = [row]

        let dueDate = Date(timeIntervalSince1970: 1_700_000_000)
        row.setCellValue(.text("Ecrire le rapport"), for: textField)
        row.setCellValue(.number(4.5), for: numberField)
        row.setCellValue(.date(dueDate), for: dateField)
        row.setCellValue(.checkbox(true), for: checkboxField)
        row.setCellValue(.url("https://example.com"), for: urlField)
        row.setCellValue(.singleSelect(optionA.id), for: singleSelectField)
        row.setCellValue(.multiSelect([optionA.id, optionB.id]), for: multiSelectField)

        for item in [folder, database, textField, numberField, dateField, checkboxField, urlField,
                     singleSelectField, multiSelectField, row] as [any PersistentModel] {
            context.insert(item)
        }
        for cell in row.cells ?? [] {
            context.insert(cell)
        }

        return FullPageFixture(optionA: optionA, optionB: optionB)
    }

    @Test
    func fullPageDatabaseWithEveryCellTypeRoundTripsThroughRealFetch() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let fixture = makeFullPageFixture(in: context)
        let optionA = fixture.optionA
        let optionB = fixture.optionB
        try context.save()

        let freshContext = ModelContext(container)
        let fetchedDatabases = try freshContext.fetch(FetchDescriptor<Database>())
        let fetchedDatabase = try #require(fetchedDatabases.first)
        #expect(fetchedDatabase.hostMode == .fullPage)
        #expect(fetchedDatabase.folder?.name == "Projets")
        #expect((fetchedDatabase.fields ?? []).count == 7)

        let fetchedRow = try #require(fetchedDatabase.rows?.first)
        let fetchedTextField = try #require(fetchedDatabase.fields?.first { $0.name == "Titre" })
        let fetchedSelectField = try #require(fetchedDatabase.fields?.first { $0.name == "Priorite" })
        let fetchedMultiField = try #require(fetchedDatabase.fields?.first { $0.name == "Etiquettes" })

        #expect(fetchedRow.cellValue(forFieldID: fetchedTextField.id) == .text("Ecrire le rapport"))
        #expect(fetchedRow.cellValue(forFieldID: fetchedSelectField.id) == .singleSelect(optionA.id))
        if case .multiSelect(let ids)? = fetchedRow.cellValue(forFieldID: fetchedMultiField.id) {
            #expect(Set(ids) == Set([optionA.id, optionB.id]))
        } else {
            Issue.record("La valeur multiSelect n'a pas survecu au round-trip")
        }

        let fetchedSelectConfig = try #require(fetchedSelectField.configuration)
        #expect(fetchedSelectConfig.selectOptions?.map(\.label) == ["Haute", "Basse"])
    }

    @Test
    func inlineDatabaseHostedByBlockRoundTripsThroughRealFetch() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let note = Note(title: "Note avec base inline")
        let block = Block(order: 0, type: .databaseView, note: note)
        let database = Database(name: "Suivi", hostMode: .inline, hostBlock: block)
        block.databaseView = database
        note.blocks = [block]

        for item in [note, block, database] as [any PersistentModel] {
            context.insert(item)
        }
        try context.save()

        let freshContext = ModelContext(container)
        let fetchedBlocks = try freshContext.fetch(FetchDescriptor<Block>())
        let fetchedBlock = try #require(fetchedBlocks.first)
        #expect(fetchedBlock.databaseView?.name == "Suivi")
        #expect(fetchedBlock.databaseView?.hostMode == .inline)
    }

    @Test
    func deletingFieldCascadesToItsCellsOnly() throws {
        let context = ModelContext(try makeContainer())
        let database = Database(name: "Base")
        let fieldToDelete = DatabaseField(name: "A supprimer", order: 0, fieldType: .text, database: database)
        let survivingField = DatabaseField(name: "Restant", order: 1, fieldType: .text, database: database)
        database.fields = [fieldToDelete, survivingField]
        let row = DatabaseRow(database: database)
        database.rows = [row]
        row.setCellValue(.text("valeur 1"), for: fieldToDelete)
        row.setCellValue(.text("valeur 2"), for: survivingField)

        for item in [database, fieldToDelete, survivingField, row] as [any PersistentModel] {
            context.insert(item)
        }
        for cell in row.cells ?? [] { context.insert(cell) }
        try context.save()

        #expect(try context.fetch(FetchDescriptor<DatabaseCell>()).count == 2)

        Database.deleteField(fieldToDelete, from: context)
        try context.save()

        let remainingCells = try context.fetch(FetchDescriptor<DatabaseCell>())
        #expect(remainingCells.count == 1)
        #expect(remainingCells.first?.field?.name == "Restant")
        #expect(try context.fetch(FetchDescriptor<DatabaseField>()).count == 1)
    }

    @Test
    func deletingRowCascadesToItsCellsOnly() throws {
        let context = ModelContext(try makeContainer())
        let database = Database(name: "Base")
        let field = DatabaseField(name: "Titre", order: 0, fieldType: .text, database: database)
        database.fields = [field]
        let rowToDelete = DatabaseRow(database: database)
        let survivingRow = DatabaseRow(database: database)
        database.rows = [rowToDelete, survivingRow]
        rowToDelete.setCellValue(.text("a"), for: field)
        survivingRow.setCellValue(.text("b"), for: field)

        for item in [database, field, rowToDelete, survivingRow] as [any PersistentModel] {
            context.insert(item)
        }
        for cell in (rowToDelete.cells ?? []) + (survivingRow.cells ?? []) { context.insert(cell) }
        try context.save()

        Database.deleteRow(rowToDelete, from: context)
        try context.save()

        #expect(try context.fetch(FetchDescriptor<DatabaseRow>()).count == 1)
        #expect(try context.fetch(FetchDescriptor<DatabaseCell>()).count == 1)
    }

    @Test
    func deletingDatabaseLeavesNoOrphanFieldRowOrCell() throws {
        let context = ModelContext(try makeContainer())
        let database = Database(name: "A supprimer")
        let field = DatabaseField(name: "Titre", order: 0, fieldType: .text, database: database)
        database.fields = [field]
        let row = DatabaseRow(database: database)
        database.rows = [row]
        row.setCellValue(.text("valeur"), for: field)

        for item in [database, field, row] as [any PersistentModel] {
            context.insert(item)
        }
        for cell in row.cells ?? [] { context.insert(cell) }
        try context.save()

        Database.delete(database, from: context)
        try context.save()

        #expect(try context.fetch(FetchDescriptor<Database>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<DatabaseField>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<DatabaseRow>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<DatabaseCell>()).isEmpty)
    }

    @Test
    func deletingHostBlockCascadesToInlineDatabase() throws {
        let context = ModelContext(try makeContainer())
        let note = Note(title: "Note")
        let block = Block(order: 0, type: .databaseView, note: note)
        let database = Database(name: "Inline", hostMode: .inline, hostBlock: block)
        block.databaseView = database
        note.blocks = [block]

        for item in [note, block, database] as [any PersistentModel] {
            context.insert(item)
        }
        try context.save()

        context.delete(block)
        try context.save()

        #expect(try context.fetch(FetchDescriptor<Database>()).isEmpty)
    }
}
