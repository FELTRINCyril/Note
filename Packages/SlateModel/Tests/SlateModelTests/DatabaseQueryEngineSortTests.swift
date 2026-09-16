import Foundation
import Testing

@testable import SlateModel

/// Phase 17.4 : tris multi-niveaux, en Swift pur.
struct DatabaseQueryEngineSortTests {
    private let categoryFieldID = UUID()
    private let scoreFieldID = UUID()

    private func fields() -> [DatabaseFieldSnapshot] {
        [
            DatabaseFieldSnapshot(
                id: categoryFieldID, name: "Categorie", order: 0, type: .text, configuration: .init()
            ),
            DatabaseFieldSnapshot(id: scoreFieldID, name: "Score", order: 1, type: .number, configuration: .init())
        ]
    }

    private func row(category: String, score: Double?) -> DatabaseRowSnapshot {
        var values: [UUID: CellValue] = [categoryFieldID: .text(category)]
        if let score { values[scoreFieldID] = .number(score) }
        return DatabaseRowSnapshot(id: UUID(), order: 0, createdAt: .now, modifiedAt: .now, values: values)
    }

    @Test
    func singleLevelAscendingNumberSort() {
        let rows = [row(category: "A", score: 3), row(category: "A", score: 1), row(category: "A", score: 2)]
        let sorted = DatabaseQueryEngine.sort(
            rows,
            by: [DatabaseSortDescriptor(fieldID: scoreFieldID, direction: .ascending)],
            fields: fields()
        )
        let scores: [Double] = sorted.compactMap {
            if case .number(let value)? = $0.values[scoreFieldID] { value } else { nil }
        }
        #expect(scores == [1, 2, 3])
    }

    @Test
    func multiLevelSortUsesSecondCriterionToBreakTies() {
        let rows = [
            row(category: "B", score: 1),
            row(category: "A", score: 2),
            row(category: "A", score: 1)
        ]
        let sorted = DatabaseQueryEngine.sort(
            rows,
            by: [
                DatabaseSortDescriptor(fieldID: categoryFieldID, direction: .ascending),
                DatabaseSortDescriptor(fieldID: scoreFieldID, direction: .descending)
            ],
            fields: fields()
        )
        let categories = sorted.map { if case .text(let value)? = $0.values[categoryFieldID] { value } else { "" } }
        #expect(categories == ["A", "A", "B"])
        let firstTwoScores: [Double] = sorted.prefix(2).map {
            if case .number(let value)? = $0.values[scoreFieldID] { value } else { 0 }
        }
        #expect(firstTwoScores == [2, 1])
    }

    @Test
    func rowsWithMissingValueAlwaysSortLastRegardlessOfDirection() {
        let withScore = row(category: "A", score: 1)
        let withoutScore = row(category: "B", score: nil)

        let ascending = DatabaseQueryEngine.sort(
            [withoutScore, withScore],
            by: [DatabaseSortDescriptor(fieldID: scoreFieldID, direction: .ascending)],
            fields: fields()
        )
        #expect(ascending.last?.id == withoutScore.id)

        let descending = DatabaseQueryEngine.sort(
            [withoutScore, withScore],
            by: [DatabaseSortDescriptor(fieldID: scoreFieldID, direction: .descending)],
            fields: fields()
        )
        #expect(descending.last?.id == withoutScore.id)
    }

    @Test
    func emptyDescriptorListPreservesOriginalOrder() {
        let rows = [row(category: "B", score: 1), row(category: "A", score: 2)]
        let sorted = DatabaseQueryEngine.sort(rows, by: [], fields: fields())
        #expect(sorted.map(\.id) == rows.map(\.id))
    }
}
