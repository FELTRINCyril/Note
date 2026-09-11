import Foundation
import Testing

@testable import SlateModel

/// Verifie que `BlockAttributes` (1) se serialise/deserialise a l'identique et (2)
/// tolere des donnees JSON auxquelles il manque des champs (simule des donnees ecrites
/// par une version plus ancienne de l'app, avant l'ajout d'un champ).
struct BlockAttributesTests {

    @Test
    func roundTripsAllFieldsThroughJSON() throws {
        let attributes = BlockAttributes(
            language: "swift",
            headingLevel: 2,
            isChecked: true,
            calloutIcon: "lightbulb",
            calloutVariant: "warning",
            imageWidth: 320,
            imageHeight: 200,
            imageAltText: "Un schema",
            columnWidthRatio: 0.5,
            columnCount: 2,
            isHeaderRow: true,
            columnWidth: 184,
            linkedNoteID: UUID(),
            sourceURLString: "https://example.com"
        )

        let data = try JSONEncoder().encode(attributes)
        let decoded = try JSONDecoder().decode(BlockAttributes.self, from: data)

        #expect(decoded == attributes)
    }

    @Test
    func decodingToleratesMissingFieldsWithDefaults() throws {
        // Simule des donnees ecrites avant l'ajout de tous les champs sauf `language` :
        // seul `language` est present dans le JSON.
        let legacyJSON = Data("""
        { "language": "python" }
        """.utf8)

        let decoded = try JSONDecoder().decode(BlockAttributes.self, from: legacyJSON)

        #expect(decoded.language == "python")
        #expect(decoded.isChecked == false)
        #expect(decoded.headingLevel == nil)
        #expect(decoded.imageWidth == nil)
        #expect(decoded.linkedNoteID == nil)
        #expect(decoded.isHeaderRow == false)
        #expect(decoded.columnWidth == nil)
        #expect(decoded.calloutVariant == nil)
    }

    @Test
    func decodingCompletelyEmptyObjectUsesAllDefaults() throws {
        let emptyJSON = Data("{}".utf8)

        let decoded = try JSONDecoder().decode(BlockAttributes.self, from: emptyJSON)

        #expect(decoded == BlockAttributes())
    }

    @Test
    func decodingIgnoresUnknownFutureFields() throws {
        // Simule des donnees ecrites par une version *future* de l'app, qui a ajoute
        // un champ que cette version ne connait pas encore.
        let futureJSON = Data("""
        { "language": "swift", "someFutureField": "valeur inconnue" }
        """.utf8)

        let decoded = try JSONDecoder().decode(BlockAttributes.self, from: futureJSON)

        #expect(decoded.language == "swift")
    }
}
