import Foundation
import SwiftData
import Testing

@testable import SlateModel

/// Phase 17.2/17.4 : relations entre deux bases, rollups, et les invariants d'integrite
/// exiges par `docs/17_base_de_donnees.md` - en particulier "une relation dont la cible
/// disparait ne doit pas produire de reference morte silencieuse" et "un rollup dont le
/// champ source disparait doit se comporter proprement".
struct DatabaseRelationRollupTests {
    // MARK: - Evaluation pure (snapshots), sans ModelContext

    @Test
    func rollupSumsTargetFieldAcrossRelatedRows() {
        let budgetFieldID = UUID()
        let projectA = DatabaseRowSnapshot(
            id: UUID(), order: 0, createdAt: .now, modifiedAt: .now, values: [budgetFieldID: .number(100)]
        )
        let projectB = DatabaseRowSnapshot(
            id: UUID(), order: 1, createdAt: .now, modifiedAt: .now, values: [budgetFieldID: .number(50)]
        )
        let projectsDatabaseID = UUID()
        let projectsFields = [
            DatabaseFieldSnapshot(id: budgetFieldID, name: "Budget", order: 0, type: .number, configuration: .init())
        ]
        let projectsDatabase = DatabaseSnapshot(
            id: projectsDatabaseID, fields: projectsFields, rows: [projectA, projectB]
        )

        let relationFieldID = UUID()
        let rollupFieldID = UUID()
        let taskFields = [
            DatabaseFieldSnapshot(
                id: relationFieldID, name: "Projets", order: 0, type: .relation,
                configuration: DatabaseFieldConfiguration(relationTargetDatabaseID: projectsDatabaseID)
            ),
            DatabaseFieldSnapshot(
                id: rollupFieldID, name: "Budget total", order: 1, type: .rollup,
                configuration: DatabaseFieldConfiguration(
                    rollupSourceFieldID: relationFieldID,
                    rollupTargetFieldID: budgetFieldID,
                    rollupOperation: .sum
                )
            )
        ]
        let task = DatabaseRowSnapshot(
            id: UUID(), order: 0, createdAt: .now, modifiedAt: .now,
            values: [relationFieldID: .relation([projectA.id, projectB.id])]
        )

        let value = DatabaseQueryEngine.evaluatedValue(
            for: rollupFieldID,
            in: task,
            fields: taskFields,
            relatedDatabases: [projectsDatabaseID: projectsDatabase]
        )
        #expect(value == .number(150))
    }

    @Test
    func rollupReturnsNilWhenSourceRelationFieldNoLongerExists() {
        let rollupFieldID = UUID()
        let missingSourceID = UUID()
        let taskFields = [
            DatabaseFieldSnapshot(
                id: rollupFieldID, name: "Budget total", order: 0, type: .rollup,
                configuration: DatabaseFieldConfiguration(
                    rollupSourceFieldID: missingSourceID,
                    rollupTargetFieldID: UUID(),
                    rollupOperation: .sum
                )
            )
        ]
        let task = DatabaseRowSnapshot(
            id: UUID(), order: 0, createdAt: .now, modifiedAt: .now, values: [:]
        )

        let value = DatabaseQueryEngine.evaluatedValue(
            for: rollupFieldID, in: task, fields: taskFields, relatedDatabases: [:]
        )
        #expect(value == nil)
    }

    @Test
    func rollupReturnsNilWhenRelatedDatabaseIsNotProvided() {
        let relationFieldID = UUID()
        let rollupFieldID = UUID()
        let taskFields = [
            DatabaseFieldSnapshot(
                id: relationFieldID, name: "Projets", order: 0, type: .relation,
                configuration: DatabaseFieldConfiguration(relationTargetDatabaseID: UUID())
            ),
            DatabaseFieldSnapshot(
                id: rollupFieldID, name: "Budget total", order: 1, type: .rollup,
                configuration: DatabaseFieldConfiguration(
                    rollupSourceFieldID: relationFieldID,
                    rollupTargetFieldID: UUID(),
                    rollupOperation: .sum
                )
            )
        ]
        let task = DatabaseRowSnapshot(
            id: UUID(), order: 0, createdAt: .now, modifiedAt: .now,
            values: [relationFieldID: .relation([UUID()])]
        )

        let value = DatabaseQueryEngine.evaluatedValue(
            for: rollupFieldID, in: task, fields: taskFields, relatedDatabases: [:]
        )
        #expect(value == nil)
    }

    // MARK: - Integrite reelle (ModelContext), suppression sans reference morte

    @MainActor
    @Test
    func deletingRowCleansDeadRelationReferenceInAnotherDatabase() throws {
        let container = try SlateContainer.make(inMemory: true)
        let context = ModelContext(container)

        let projects = Database(name: "Projets")
        let projectRow = DatabaseRow(database: projects)
        projects.rows = [projectRow]

        let tasks = Database(name: "Taches")
        let relationField = DatabaseField(
            name: "Projet",
            order: 0,
            fieldType: .relation,
            database: tasks,
            configuration: DatabaseFieldConfiguration(relationTargetDatabaseID: projects.id)
        )
        tasks.fields = [relationField]
        let taskRow = DatabaseRow(database: tasks)
        tasks.rows = [taskRow]
        taskRow.setCellValue(.relation([projectRow.id]), for: relationField)

        for item in [projects, projectRow, tasks, relationField, taskRow] as [any PersistentModel] {
            context.insert(item)
        }
        for cell in taskRow.cells ?? [] { context.insert(cell) }
        try context.save()

        Database.deleteRow(projectRow, from: context, relatedDatabases: [tasks])
        try context.save()

        let freshContext = ModelContext(container)
        let fetchedTasks = try #require(
            try freshContext.fetch(FetchDescriptor<Database>()).first { $0.name == "Taches" }
        )
        let fetchedField = try #require(fetchedTasks.fields?.first)
        let fetchedRow = try #require(fetchedTasks.rows?.first)
        #expect(fetchedRow.cellValue(forFieldID: fetchedField.id) == .relation([]))
        #expect(try freshContext.fetch(FetchDescriptor<DatabaseRow>()).count == 1)
    }

    @MainActor
    @Test
    func deletingRelationFieldClearsDependentRollupConfiguration() throws {
        let container = try SlateContainer.make(inMemory: true)
        let context = ModelContext(container)

        let projects = Database(name: "Projets")
        let budgetField = DatabaseField(name: "Budget", order: 0, fieldType: .number, database: projects)
        projects.fields = [budgetField]

        let tasks = Database(name: "Taches")
        let relationField = DatabaseField(
            name: "Projet",
            order: 0,
            fieldType: .relation,
            database: tasks,
            configuration: DatabaseFieldConfiguration(relationTargetDatabaseID: projects.id)
        )
        let rollupField = DatabaseField(
            name: "Budget total",
            order: 1,
            fieldType: .rollup,
            database: tasks,
            configuration: DatabaseFieldConfiguration(
                rollupSourceFieldID: relationField.id,
                rollupTargetFieldID: budgetField.id,
                rollupOperation: .sum
            )
        )
        tasks.fields = [relationField, rollupField]

        for item in [projects, budgetField, tasks, relationField, rollupField] as [any PersistentModel] {
            context.insert(item)
        }
        try context.save()

        Database.deleteField(relationField, from: context)
        try context.save()

        let freshContext = ModelContext(container)
        let fetchedTasks = try #require(
            try freshContext.fetch(FetchDescriptor<Database>()).first { $0.name == "Taches" }
        )
        let fetchedRollup = try #require(fetchedTasks.fields?.first { $0.name == "Budget total" })
        #expect(fetchedRollup.configuration?.rollupSourceFieldID == nil)
        #expect(fetchedRollup.configuration?.rollupOperation == nil)
    }

    @MainActor
    @Test
    func deletingTargetDatabaseClearsRelationConfigurationAndValuesElsewhere() throws {
        let container = try SlateContainer.make(inMemory: true)
        let context = ModelContext(container)

        let projects = Database(name: "Projets")
        let projectRow = DatabaseRow(database: projects)
        projects.rows = [projectRow]

        let tasks = Database(name: "Taches")
        let relationField = DatabaseField(
            name: "Projet",
            order: 0,
            fieldType: .relation,
            database: tasks,
            configuration: DatabaseFieldConfiguration(relationTargetDatabaseID: projects.id)
        )
        tasks.fields = [relationField]
        let taskRow = DatabaseRow(database: tasks)
        tasks.rows = [taskRow]
        taskRow.setCellValue(.relation([projectRow.id]), for: relationField)

        for item in [projects, projectRow, tasks, relationField, taskRow] as [any PersistentModel] {
            context.insert(item)
        }
        for cell in taskRow.cells ?? [] { context.insert(cell) }
        try context.save()

        Database.delete(projects, from: context, relatedDatabases: [tasks])
        try context.save()

        let freshContext = ModelContext(container)
        #expect(try freshContext.fetch(FetchDescriptor<Database>()).count == 1)
        let fetchedTasks = try #require(try freshContext.fetch(FetchDescriptor<Database>()).first)
        let fetchedField = try #require(fetchedTasks.fields?.first)
        #expect(fetchedField.configuration?.relationTargetDatabaseID == nil)
        let fetchedRow = try #require(fetchedTasks.rows?.first)
        #expect(fetchedRow.cellValue(forFieldID: fetchedField.id) == nil)
    }
}
