import SlateModel
import Testing

@testable import SlateEditor

/// Exhaustivite du routage `BlockType` -> `BlockRenderKind` (voir
/// `BlockRenderRouting.kind(for:)`) : le `switch` interne est exhaustif au sens du
/// compilateur (pas de `default`), ce test verifie en plus que le MAPPAGE lui-meme
/// reste correct pour chaque cas et que les 23 `BlockType` sont bien couverts par
/// `BlockType.allCases` (aucun type oublie).
@Suite("BlockRenderRouting")
struct BlockRenderRoutingTests {
    @Test("Tous les BlockType sont routes sans exception")
    func allBlockTypesAreRouted() {
        for type in BlockType.allCases {
            // Doit simplement ne jamais planter/lever : appeler la fonction sur
            // chaque cas suffit a prouver l'exhaustivite du switch au moment ou ce
            // test est compile (un BlockType nouveau non traite serait une erreur de
            // COMPILATION dans BlockRenderRouting.kind(for:), pas un echec ici).
            _ = BlockRenderRouting.kind(for: type)
        }
        #expect(BlockType.allCases.count == 23)
    }

    @Test("Le paragraphe et les titres routent vers les cas attendus")
    func paragraphAndHeadings() {
        #expect(BlockRenderRouting.kind(for: .paragraph) == .paragraph)
        #expect(BlockRenderRouting.kind(for: .heading1) == .heading(level: 1))
        #expect(BlockRenderRouting.kind(for: .heading2) == .heading(level: 2))
        #expect(BlockRenderRouting.kind(for: .heading3) == .heading(level: 3))
        #expect(BlockRenderRouting.kind(for: .heading4) == .heading(level: 4))
        #expect(BlockRenderRouting.kind(for: .heading5) == .heading(level: 5))
        #expect(BlockRenderRouting.kind(for: .heading6) == .heading(level: 6))
    }

    @Test("Les listes, la citation et le code routent vers un rendu dedie")
    func listsQuoteCode() {
        #expect(BlockRenderRouting.kind(for: .bulletedList) == .bulletedListItem)
        #expect(BlockRenderRouting.kind(for: .numberedList) == .numberedListItem)
        #expect(BlockRenderRouting.kind(for: .todo) == .todoItem)
        #expect(BlockRenderRouting.kind(for: .quote) == .quote)
        #expect(BlockRenderRouting.kind(for: .code) == .code)
        #expect(BlockRenderRouting.kind(for: .divider) == .divider)
    }

    @Test("Les blocs riches hors perimetre routent vers le rendu de repli, avec leur type d'origine")
    func outOfScopeTypesRouteToUnsupported() {
        let outOfScope: [BlockType] = [
            .callout, .image, .file, .table, .columnList, .column,
            .bookmark, .embed, .databaseView, .pageLink
        ]
        for type in outOfScope {
            #expect(BlockRenderRouting.kind(for: type) == .unsupported(type))
        }
    }
}
