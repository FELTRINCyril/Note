import Foundation
import Testing

@testable import SlateModel

/// Phase 17.4 : calculs de colonne (barre de calculs de la vue Grille), y compris sur
/// colonne vide et valeurs manquantes.
struct DatabaseQueryEngineCalculationTests {
    private let scoreFieldID = UUID()
    private let titleFieldID = UUID()

    private func fields() -> [DatabaseFieldSnapshot] {
        [
            DatabaseFieldSnapshot(id: scoreFieldID, name: "Score", order: 0, type: .number, configuration: .init()),
            DatabaseFieldSnapshot(id: titleFieldID, name: "Titre", order: 1, type: .text, configuration: .init())
        ]
    }

    private func row(score: Double?) -> DatabaseRowSnapshot {
        var values: [UUID: CellValue] = [:]
        if let score { values[scoreFieldID] = .number(score) }
        return DatabaseRowSnapshot(id: UUID(), order: 0, createdAt: .now, modifiedAt: .now, values: values)
    }

    private func calculate(
        _ calculation: DatabaseColumnCalculation,
        fieldID: UUID,
        in rows: [DatabaseRowSnapshot]
    ) -> DatabaseCalculationResult {
        DatabaseQueryEngine.calculate(calculation, fieldID: fieldID, in: rows, fields: fields())
    }

    @Test
    func sumAverageMinMaxIgnoreMissingValues() {
        let rows = [row(score: 2), row(score: 4), row(score: nil), row(score: 6)]

        #expect(calculate(.sum, fieldID: scoreFieldID, in: rows) == .number(12))
        #expect(calculate(.average, fieldID: scoreFieldID, in: rows) == .number(4))
        #expect(calculate(.min, fieldID: scoreFieldID, in: rows) == .number(2))
        #expect(calculate(.max, fieldID: scoreFieldID, in: rows) == .number(6))
    }

    @Test
    func countFilledAndCountEmpty() {
        let rows = [row(score: 1), row(score: nil), row(score: nil)]
        #expect(calculate(.count, fieldID: scoreFieldID, in: rows) == .count(3))
        #expect(calculate(.countFilled, fieldID: scoreFieldID, in: rows) == .count(1))
        #expect(calculate(.countEmpty, fieldID: scoreFieldID, in: rows) == .count(2))
    }

    @Test
    func percentFilledAndPercentEmpty() {
        let rows = [row(score: 1), row(score: 2), row(score: nil), row(score: nil)]
        #expect(calculate(.percentFilled, fieldID: scoreFieldID, in: rows) == .percent(0.5))
        #expect(calculate(.percentEmpty, fieldID: scoreFieldID, in: rows) == .percent(0.5))
    }

    @Test
    func numericAggregatesOnEmptyColumnReturnEmpty() {
        let rows = [row(score: nil), row(score: nil)]
        #expect(calculate(.sum, fieldID: scoreFieldID, in: rows) == .empty)
        #expect(calculate(.average, fieldID: scoreFieldID, in: rows) == .empty)
        #expect(calculate(.min, fieldID: scoreFieldID, in: rows) == .empty)
        #expect(calculate(.max, fieldID: scoreFieldID, in: rows) == .empty)
    }

    @Test
    func numericAggregateOnNonNumericFieldReturnsEmpty() {
        let rows = [
            DatabaseRowSnapshot(
                id: UUID(), order: 0, createdAt: .now, modifiedAt: .now, values: [titleFieldID: .text("A")]
            )
        ]
        #expect(calculate(.sum, fieldID: titleFieldID, in: rows) == .empty)
    }

    @Test
    func noneCalculationAlwaysReturnsEmpty() {
        let rows = [row(score: 1)]
        #expect(calculate(.none, fieldID: scoreFieldID, in: rows) == .empty)
    }

    @Test
    func calculationsOnEmptyRowListAreWellDefined() {
        #expect(calculate(.count, fieldID: scoreFieldID, in: []) == .count(0))
        #expect(calculate(.sum, fieldID: scoreFieldID, in: []) == .empty)
        #expect(calculate(.percentFilled, fieldID: scoreFieldID, in: []) == .empty)
    }
}
