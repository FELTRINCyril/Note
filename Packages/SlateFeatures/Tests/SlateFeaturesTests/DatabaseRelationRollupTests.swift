import Foundation
import SwiftData
import Testing
import SlateModel
@testable import SlateFeatures

/// Configuration d'un champ `.relation`/`.rollup` depuis `DatabaseFieldEditorSheet`
/// (Phase 17, critere d'acceptation explicite "Relations + rollups corrects",
/// `docs/17_base_de_donnees.md`) : ces tests exercent exactement le chemin ecrit par
/// `DatabaseFieldEditorSheet.commit()` (`DatabaseViewModel.updateFieldConfiguration`),
/// sans instancier la vue SwiftUI elle-meme -- meme convention que le reste du module
/// (logique testee independamment de la hierarchie de vues, voir
/// `NoteListView.shouldFlattenDateGroups`).
@MainActor
@Suite("DatabaseFieldEditorSheet - configuration relation/rollup")
struct DatabaseRelationRollupTests {
    private struct Fixture {
        let projects: Database
        let projectsViewModel: DatabaseViewModel
        let relationField: DatabaseField
        let rollupField: DatabaseField
        let tasks: Database
        let effortField: DatabaseField
        let context: ModelContext
    }

    /// Deux bases pleine page : "Projets" (avec un champ `.relation` vers "Taches" et
    /// un champ `.rollup` non encore configure) et "Taches" (un champ Nombre
    /// "Effort").
    private func makeFixture() throws -> Fixture {
        let container = try SlateContainer.make(inMemory: true)
        let context = ModelContext(container)

        let tasks = Database(name: "Taches", hostMode: .fullPage)
        let effortField = DatabaseField(name: "Effort", order: 0, fieldType: .number, database: tasks)
        tasks.fields = [effortField]
        context.insert(tasks)
        context.insert(effortField)

        let projects = Database(name: "Projets", hostMode: .fullPage)
        let relationField = DatabaseField(name: "Taches liees", order: 0, fieldType: .relation, database: projects)
        let rollupField = DatabaseField(name: "Effort total", order: 1, fieldType: .rollup, database: projects)
        projects.fields = [relationField, rollupField]
        context.insert(projects)
        context.insert(relationField)
        context.insert(rollupField)
        try context.save()

        let projectsViewModel = DatabaseViewModel(database: projects, modelContext: context, relatedDatabases: [tasks])
        return Fixture(
            projects: projects,
            projectsViewModel: projectsViewModel,
            relationField: relationField,
            rollupField: rollupField,
            tasks: tasks,
            effortField: effortField,
            context: context
        )
    }

    @Test("Configurer un champ relation avec une base cible : la cellule pointe reellement vers ses lignes")
    func configuringRelationTargetProducesUsableField() throws {
        let fixture = try makeFixture()
        let tasksViewModel = DatabaseViewModel(database: fixture.tasks, modelContext: fixture.context)
        let task1 = tasksViewModel.addRow(prefilledWith: [fixture.effortField.id: .number(3)])
        let task2 = tasksViewModel.addRow(prefilledWith: [fixture.effortField.id: .number(5)])

        // Meme ecriture que `DatabaseFieldEditorSheet.commit()` pour un champ `.relation`.
        fixture.projectsViewModel.updateFieldConfiguration(
            fixture.relationField.id,
            DatabaseFieldConfiguration(relationTargetDatabaseID: fixture.tasks.id)
        )

        let project = fixture.projectsViewModel.addRow()
        fixture.projectsViewModel.setCellValue(
            .relation([task1.id, task2.id]), rowID: project.id, fieldID: fixture.relationField.id
        )

        let updatedField = fixture.projectsViewModel.snapshot.field(withID: fixture.relationField.id)
        #expect(updatedField?.configuration.relationTargetDatabaseID == fixture.tasks.id)
        let row = fixture.projectsViewModel.visibleRows.first { $0.id == project.id }
        let value = row.flatMap { fixture.projectsViewModel.evaluatedValue(fieldID: fixture.relationField.id, row: $0) }
        #expect(value == .relation([task1.id, task2.id]))
    }

    @Test("Configurer un rollup (relation + champ cible + operation) produit la valeur agregee attendue")
    func configuringRollupProducesAggregatedValue() throws {
        let fixture = try makeFixture()
        let tasksViewModel = DatabaseViewModel(database: fixture.tasks, modelContext: fixture.context)
        let task1 = tasksViewModel.addRow(prefilledWith: [fixture.effortField.id: .number(3)])
        let task2 = tasksViewModel.addRow(prefilledWith: [fixture.effortField.id: .number(5)])

        fixture.projectsViewModel.updateFieldConfiguration(
            fixture.relationField.id,
            DatabaseFieldConfiguration(relationTargetDatabaseID: fixture.tasks.id)
        )
        // Meme ecriture que `DatabaseFieldEditorSheet.commit()` pour un champ `.rollup`.
        fixture.projectsViewModel.updateFieldConfiguration(
            fixture.rollupField.id,
            DatabaseFieldConfiguration(
                rollupSourceFieldID: fixture.relationField.id,
                rollupTargetFieldID: fixture.effortField.id,
                rollupOperation: .sum
            )
        )

        let project = fixture.projectsViewModel.addRow()
        fixture.projectsViewModel.setCellValue(
            .relation([task1.id, task2.id]), rowID: project.id, fieldID: fixture.relationField.id
        )

        let row = try #require(fixture.projectsViewModel.visibleRows.first { $0.id == project.id })
        let aggregated = fixture.projectsViewModel.evaluatedValue(fieldID: fixture.rollupField.id, row: row)
        #expect(aggregated == .number(8))
    }

    @Test("Un rollup dont la relation source est vide se comporte proprement, sans crash")
    func rollupWithEmptyRelationIsHarmless() throws {
        let fixture = try makeFixture()
        fixture.projectsViewModel.updateFieldConfiguration(
            fixture.relationField.id,
            DatabaseFieldConfiguration(relationTargetDatabaseID: fixture.tasks.id)
        )
        fixture.projectsViewModel.updateFieldConfiguration(
            fixture.rollupField.id,
            DatabaseFieldConfiguration(
                rollupSourceFieldID: fixture.relationField.id,
                rollupTargetFieldID: fixture.effortField.id,
                rollupOperation: .sum
            )
        )

        let project = fixture.projectsViewModel.addRow()
        let row = try #require(fixture.projectsViewModel.visibleRows.first { $0.id == project.id })
        let aggregated = fixture.projectsViewModel.evaluatedValue(fieldID: fixture.rollupField.id, row: row)
        #expect(aggregated == nil)
    }
}
