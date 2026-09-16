import Foundation
import Testing

@testable import SlateModel

/// Phase 17.4 : regroupement (`group by`), base commune de la vue Kanban.
struct DatabaseQueryEngineGroupingTests {
    private let priorityFieldID = UUID()
    private let tagsFieldID = UUID()
    private let doneFieldID = UUID()
    private let optionHigh = UUID()
    private let optionLow = UUID()

    private func selectFields() -> [DatabaseFieldSnapshot] {
        let options = [
            DatabaseSelectOption(id: optionHigh, label: "Haute", colorToken: "red"),
            DatabaseSelectOption(id: optionLow, label: "Basse", colorToken: "blue")
        ]
        return [
            DatabaseFieldSnapshot(
                id: priorityFieldID, name: "Priorite", order: 0, type: .singleSelect,
                configuration: DatabaseFieldConfiguration(selectOptions: options)
            ),
            DatabaseFieldSnapshot(
                id: tagsFieldID, name: "Etiquettes", order: 1, type: .multiSelect,
                configuration: DatabaseFieldConfiguration(selectOptions: options)
            ),
            DatabaseFieldSnapshot(id: doneFieldID, name: "Fait", order: 2, type: .checkbox, configuration: .init())
        ]
    }

    private func row(
        priority: UUID? = nil,
        tags: [UUID]? = nil,
        // swiftlint:disable:next discouraged_optional_boolean
        done: Bool? = nil
    ) -> DatabaseRowSnapshot {
        var values: [UUID: CellValue] = [:]
        if let priority { values[priorityFieldID] = .singleSelect(priority) }
        if let tags { values[tagsFieldID] = .multiSelect(tags) }
        if let done { values[doneFieldID] = .checkbox(done) }
        return DatabaseRowSnapshot(id: UUID(), order: 0, createdAt: .now, modifiedAt: .now, values: values)
    }

    @Test
    func groupsBySingleSelectFollowOptionOrderWithEmptyLast() {
        let rows = [row(priority: optionLow), row(), row(priority: optionHigh), row(priority: optionHigh)]
        let groups = DatabaseQueryEngine.group(rows, by: priorityFieldID, fields: selectFields())

        #expect(groups.map(\.key) == [.option(optionHigh), .option(optionLow), .empty])
        #expect(groups[0].rows.count == 2)
        #expect(groups[1].rows.count == 1)
        #expect(groups[2].rows.count == 1)
    }

    @Test
    func multiSelectRowAppearsInEveryMatchingGroup() {
        let rows = [row(tags: [optionHigh, optionLow]), row(tags: [optionHigh])]
        let groups = DatabaseQueryEngine.group(rows, by: tagsFieldID, fields: selectFields())

        let highGroup = groups.first { $0.key == .option(optionHigh) }
        let lowGroup = groups.first { $0.key == .option(optionLow) }
        #expect(highGroup?.rows.count == 2)
        #expect(lowGroup?.rows.count == 1)
    }

    @Test
    func checkboxGroupsIntoTrueAndFalse() {
        let rows = [row(done: true), row(done: false), row(done: true)]
        let groups = DatabaseQueryEngine.group(rows, by: doneFieldID, fields: selectFields())
        #expect(Set(groups.map(\.key)) == Set([.boolean(true), .boolean(false)]))
    }

    @Test
    func groupingByUnknownFieldReturnsNoGroups() {
        let rows = [row(priority: optionHigh)]
        let groups = DatabaseQueryEngine.group(rows, by: UUID(), fields: selectFields())
        #expect(groups.isEmpty)
    }
}
