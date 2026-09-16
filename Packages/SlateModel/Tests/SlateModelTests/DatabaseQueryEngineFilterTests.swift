import Foundation
import Testing

@testable import SlateModel

/// Phase 17.4 : filtres par type de champ, en Swift pur (aucun `ModelContext`).
struct DatabaseQueryEngineFilterTests {
    private let titleFieldID = UUID()
    private let scoreFieldID = UUID()
    private let dueFieldID = UUID()
    private let doneFieldID = UUID()
    private let priorityFieldID = UUID()
    private let tagsFieldID = UUID()
    private let optionHigh = UUID()
    private let optionLow = UUID()

    private func fields() -> [DatabaseFieldSnapshot] {
        [
            DatabaseFieldSnapshot(id: titleFieldID, name: "Titre", order: 0, type: .text, configuration: .init()),
            DatabaseFieldSnapshot(id: scoreFieldID, name: "Score", order: 1, type: .number, configuration: .init()),
            DatabaseFieldSnapshot(id: dueFieldID, name: "Echeance", order: 2, type: .date, configuration: .init()),
            DatabaseFieldSnapshot(id: doneFieldID, name: "Fait", order: 3, type: .checkbox, configuration: .init()),
            DatabaseFieldSnapshot(
                id: priorityFieldID, name: "Priorite", order: 4, type: .singleSelect, configuration: .init()
            ),
            DatabaseFieldSnapshot(
                id: tagsFieldID, name: "Etiquettes", order: 5, type: .multiSelect, configuration: .init()
            )
        ]
    }

    /// `done` doit rester un `Bool?` (et non `Bool = false`) : ce test verifie
    /// explicitement la difference entre "case a cocher absente" (`nil`, aucune
    /// `DatabaseCell`) et "case a cocher explicitement decochee" (`false`), voir
    /// `checkboxOperatorTreatsMissingValueAsUnchecked`.
    private func row(
        title: String? = nil,
        score: Double? = nil,
        due: Date? = nil,
        // swiftlint:disable:next discouraged_optional_boolean
        done: Bool? = nil,
        priority: UUID? = nil,
        tags: [UUID]? = nil
    ) -> DatabaseRowSnapshot {
        var values: [UUID: CellValue] = [:]
        if let title { values[titleFieldID] = .text(title) }
        if let score { values[scoreFieldID] = .number(score) }
        if let due { values[dueFieldID] = .date(due) }
        if let done { values[doneFieldID] = .checkbox(done) }
        if let priority { values[priorityFieldID] = .singleSelect(priority) }
        if let tags { values[tagsFieldID] = .multiSelect(tags) }
        return DatabaseRowSnapshot(id: UUID(), order: 0, createdAt: .now, modifiedAt: .now, values: values)
    }

    @Test
    func textContainsFiltersCaseInsensitively() {
        let rows = [row(title: "Rapport annuel"), row(title: "Facture"), row(title: nil)]
        let filter = DatabaseFilter(conditions: [.init(fieldID: titleFieldID, op: .textContains("rapport"))])
        let result = DatabaseQueryEngine.filter(rows, with: filter, fields: fields())
        #expect(result.count == 1)
    }

    @Test
    func isEmptyMatchesMissingAndBlankText() {
        let rows = [row(title: "  "), row(title: "Non vide"), row()]
        let filter = DatabaseFilter(conditions: [.init(fieldID: titleFieldID, op: .isEmpty)])
        let result = DatabaseQueryEngine.filter(rows, with: filter, fields: fields())
        #expect(result.count == 2)
    }

    @Test
    func numberComparisonOperators() {
        let rows = [row(score: 1), row(score: 5), row(score: 10), row()]
        let greaterThan = DatabaseFilter(conditions: [.init(fieldID: scoreFieldID, op: .numberGreaterThan(4))])
        #expect(DatabaseQueryEngine.filter(rows, with: greaterThan, fields: fields()).count == 2)

        let lessOrEqual = DatabaseFilter(conditions: [.init(fieldID: scoreFieldID, op: .numberLessThanOrEqual(5))])
        #expect(DatabaseQueryEngine.filter(rows, with: lessOrEqual, fields: fields()).count == 2)
    }

    @Test
    func dateBeforeAndAfterOperators() {
        let reference = Date(timeIntervalSince1970: 1_700_000_000)
        let earlier = reference.addingTimeInterval(-86_400)
        let later = reference.addingTimeInterval(86_400)
        let rows = [row(due: earlier), row(due: reference), row(due: later)]

        let before = DatabaseFilter(conditions: [.init(fieldID: dueFieldID, op: .dateIsBefore(reference))])
        #expect(DatabaseQueryEngine.filter(rows, with: before, fields: fields()).count == 1)

        let onOrAfter = DatabaseFilter(conditions: [.init(fieldID: dueFieldID, op: .dateIsOnOrAfter(reference))])
        #expect(DatabaseQueryEngine.filter(rows, with: onOrAfter, fields: fields()).count == 2)

        let sameDay = DatabaseFilter(conditions: [.init(fieldID: dueFieldID, op: .dateIsOn(reference))])
        #expect(DatabaseQueryEngine.filter(rows, with: sameDay, fields: fields()).count == 1)
    }

    @Test
    func checkboxOperatorTreatsMissingValueAsUnchecked() {
        let rows = [row(done: true), row(done: false), row()]
        let checked = DatabaseFilter(conditions: [.init(fieldID: doneFieldID, op: .checkboxIs(true))])
        #expect(DatabaseQueryEngine.filter(rows, with: checked, fields: fields()).count == 1)

        let unchecked = DatabaseFilter(conditions: [.init(fieldID: doneFieldID, op: .checkboxIs(false))])
        #expect(DatabaseQueryEngine.filter(rows, with: unchecked, fields: fields()).count == 2)
    }

    @Test
    func singleSelectIsAnyOf() {
        let rows = [row(priority: optionHigh), row(priority: optionLow), row()]
        let filter = DatabaseFilter(conditions: [.init(fieldID: priorityFieldID, op: .selectIsAnyOf([optionHigh]))])
        #expect(DatabaseQueryEngine.filter(rows, with: filter, fields: fields()).count == 1)
    }

    @Test
    func multiSelectContainsAllRequiresEveryOption() {
        let rows = [row(tags: [optionHigh, optionLow]), row(tags: [optionHigh]), row(tags: [])]
        let filter = DatabaseFilter(
            conditions: [.init(fieldID: tagsFieldID, op: .multiSelectContainsAll([optionHigh, optionLow]))]
        )
        #expect(DatabaseQueryEngine.filter(rows, with: filter, fields: fields()).count == 1)
    }

    @Test
    func orCombinatorMatchesAnyCondition() {
        let rows = [row(title: "Urgent"), row(score: 9), row(title: "Autre", score: 1)]
        let filter = DatabaseFilter(
            combinator: .or,
            conditions: [
                .init(fieldID: titleFieldID, op: .textEquals("Urgent")),
                .init(fieldID: scoreFieldID, op: .numberGreaterThan(5))
            ]
        )
        #expect(DatabaseQueryEngine.filter(rows, with: filter, fields: fields()).count == 2)
    }

    @Test
    func emptyConditionListMatchesEverything() {
        let rows = [row(title: "A"), row(title: "B")]
        let filter = DatabaseFilter()
        #expect(DatabaseQueryEngine.filter(rows, with: filter, fields: fields()).count == 2)
    }
}
